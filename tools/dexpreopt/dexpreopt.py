#!/usr/bin/env python
#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""Creates optimized versions of APK files.

A tool and associated functions to communicate with an Android
emulator instance, run commands, and scrape out files.

Requires at least python2.4.
"""

import array
import datetime
import optparse
import os
import posix
import select
import signal
import struct
import subprocess
import sys
import tempfile
import time
import zlib


_emulator_popen = None
_DEBUG_READ = 1


def EnsureTempDir(path=None):
  """Creates a temporary directory and returns its path.

  Creates any necessary parent directories.

  Args:
    path: If specified, used as the temporary directory.  If not specified,
          a safe temporary path is created.  The caller is responsible for
          deleting the directory.

  Returns:
    The path to the new directory, or None if a problem occurred.
  """
  if path is None:
    path = tempfile.mkdtemp('', 'dexpreopt-')
  elif not os.path.exists(path):
    os.makedirs(path)
  elif not os.path.isdir(path):
    return None
  return path


def CreateZeroedFile(path, length):
  """Creates the named file and writes <length> zero bytes to it.

  Unlinks the file first if it already exists.
  Creates its containing directory if necessary.

  Args:
    path: The path to the file to create.
    length: The number of zero bytes to write to the file.

  Returns:
    True on success.
  """
  subprocess.call(['rm', '-f', path])
  d = os.path.dirname(path)
  if d and not os.path.exists(d): os.makedirs(os.path.dirname(d))
  # TODO: redirect child's stdout to /dev/null
  ret = subprocess.call(['dd', 'if=/dev/zero', 'of=%s' % path,
                         'bs=%d' % length, 'count=1'])
  return not ret  # i.e., ret == 0;  i.e., the child exited successfully.


def StartEmulator(exe_name='emulator', kernel=None,
                  ramdisk=None, image=None, userdata=None, system=None):
  """Runs the emulator with the specified arguments.

  Args:
    exe_name: The name of the emulator to run.  May be absolute, relative,
              or unqualified (and left to exec() to find).
    kernel: If set, passed to the emulator as "-kernel".
    ramdisk: If set, passed to the emulator as "-ramdisk".
    image: If set, passed to the emulator as "-image".
    userdata: If set, passed to the emulator as "-initdata" and "-data".
    system: If set, passed to the emulator as "-system".

  Returns:
    A subprocess.Popen that refers to the emulator process, or None if
    a problem occurred.
  """
  #exe_name = './stuff'
  args = [exe_name]
  if kernel: args += ['-kernel', kernel]
  if ramdisk: args += ['-ramdisk', ramdisk]
  if image: args += ['-image', image]
  if userdata: args += ['-initdata', userdata, '-data', userdata]
  if system: args += ['-system', system]
  args += ['-no-window', '-netfast', '-noaudio']

  _USE_PIPE = True

  if _USE_PIPE:
    # Use dedicated fds instead of stdin/out to talk to the
    # emulator so that the emulator doesn't try to tty-cook
    # the data.
    em_stdin_r, em_stdin_w = posix.pipe()
    em_stdout_r, em_stdout_w = posix.pipe()
    args += ['-shell-serial', 'fdpair:%d:%d' % (em_stdin_r, em_stdout_w)]
  else:
    args += ['-shell']

  # Ensure that this environment variable isn't set;
  # if it is, the emulator will print the log to stdout.
  if os.environ.get('ANDROID_LOG_TAGS'):
    del os.environ['ANDROID_LOG_TAGS']

  try:
    # bufsize=1 line-buffered, =0 unbuffered,
    # <0 system default (fully buffered)
    Trace('Running emulator: %s' % ' '.join(args))
    if _USE_PIPE:
      ep = subprocess.Popen(args)
    else:
      ep = subprocess.Popen(args, close_fds=True,
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if ep:
      if _USE_PIPE:
        # Hijack the Popen.stdin/.stdout fields to point to our
        # pipes.  These are the same fields that would have been set
        # if we called Popen() with stdin=subprocess.PIPE, etc.
        # Note that these names are from the point of view of the
        # child process.
        #
        # Since we'll be using select.select() to read data a byte
        # at a time, it's important that these files are unbuffered
        # (bufsize=0).  If Popen() took care of the pipes, they're
        # already unbuffered.
        ep.stdin = os.fdopen(em_stdin_w, 'w', 0)
        ep.stdout = os.fdopen(em_stdout_r, 'r', 0)
      return ep
  except OSError, e:
    print >>sys.stderr, 'Could not start emulator:', e
  return None


def IsDataAvailable(fo, timeout=0):
  """Indicates whether or not data is available to be read from a file object.

  Args:
    fo: A file object to read from.
    timeout: The number of seconds to wait for data, or zero for no timeout.

  Returns:
    True iff data is available to be read.
  """
  return select.select([fo], [], [], timeout) == ([fo], [], [])


def ConsumeAvailableData(fo):
  """Reads data from a file object while it's available.

  Stops when no more data is immediately available or upon reaching EOF.

  Args:
    fo: A file object to read from.

  Returns:
    An unsigned byte array.array of the data that was read.
  """
  buf = array.array('B')
  while IsDataAvailable(fo):
    try:
      buf.fromfile(fo, 1)
    except EOFError:
      break
  return buf


def ShowTimeout(timeout, end_time):
    """For debugging, display the timeout info.

    Args:
      timeout: the timeout in seconds.
      end_time: a time.time()-based value indicating when the timeout should
                expire.
    """
    if _DEBUG_READ:
      if timeout:
        remaining = end_time - time.time()
        Trace('ok, time remaining %.1f of %.1f' % (remaining, timeout))
      else:
        Trace('ok (no timeout)')


def WaitForString(inf, pattern, timeout=0, max_len=0, eat_to_eol=True,
                  reset_on_activity=False):
  """Reads from a file object and returns when the pattern matches the data.

  Reads a byte at a time to avoid consuming extra data, so do not call
  this function when you expect the pattern to match a large amount of data.

  Args:
    inf: The file object to read from.
    pattern: The string to look for in the input data.
             May be a tuple of strings.
    timeout: How long to wait, in seconds. No timeout if it evaluates to False.
    max_len: Return None if this many bytes have been read without matching.
             No upper bound if it evaluates to False.
    eat_to_eol: If true, the input data will be consumed until a '\\n' or EOF
                is encountered.
    reset_on_activity: If True, reset the timeout whenever a character is
                       read.

  Returns:
    The input data matching the expression as an unsigned char array,
    or None if the operation timed out or didn't match after max_len bytes.

  Raises:
    IOError: An error occurred reading from the input file.
  """
  if timeout:
    end_time = time.time() + timeout
  else:
    end_time = 0

  if _DEBUG_READ:
    Trace('WaitForString: "%s", %.1f' % (pattern, timeout))

  buf = array.array('B')  # unsigned char array
  eating = False
  while True:
    if end_time:
      remaining = end_time - time.time()
      if remaining <= 0:
        Trace('Timeout expired after %.1f seconds' % timeout)
        return None
    else:
      remaining = None

    if IsDataAvailable(inf, remaining):
      if reset_on_activity and timeout:
        end_time = time.time() + timeout

      buf.fromfile(inf, 1)
      if _DEBUG_READ:
        c = buf.tostring()[-1:]
        ci = ord(c)
        if ci < 0x20: c = '.'
        if _DEBUG_READ > 1:
          print 'read [%c] 0x%02x' % (c, ci)

      if not eating:
        if buf.tostring().endswith(pattern):
          if eat_to_eol:
            if _DEBUG_READ > 1:
              Trace('Matched; eating to EOL')
            eating = True
          else:
            ShowTimeout(timeout, end_time)
            return buf
        if _DEBUG_READ > 2:
          print '/%s/ ? "%s"' % (pattern, buf.tostring())
      else:
        if buf.tostring()[-1:] == '\n':
          ShowTimeout(timeout, end_time)
          return buf

      if max_len and len(buf) >= max_len: return None


def WaitForEmulator(ep, timeout=0):
  """Waits for the emulator to start up and print the first prompt.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    timeout: How long to wait, in seconds. No timeout if it evaluates to False.

  Returns:
    True on success, False if the timeout occurred.
  """
  # Prime the pipe; the emulator doesn't start without this.
  print >>ep.stdin, ''

  # Wait until the console is ready and the first prompt appears.
  buf = WaitForString(ep.stdout, '#', timeout=timeout, eat_to_eol=False)
  if buf:
    Trace('Saw the prompt: "%s"' % buf.tostring())
    return True
  return False


def WaitForPrompt(ep, prompt=None, timeout=0, reset_on_activity=False):
  """Blocks until the prompt appears on ep.stdout or the timeout elapses.

  Args:
    ep: A subprocess.Popen connection to the emulator process.
    prompt: The prompt to wait for.  If None, uses ep.prompt.
    timeout: How many seconds to wait for the prompt.  Waits forever
             if timeout is zero.
    reset_on_activity: If True, reset the timeout whenever a character is
                       read.

  Returns:
    A string containing the data leading up to the prompt.  The string
    will always end in '\\n'.  Returns None if the prompt was not seen
    within the timeout, or if some other error occurred.
  """
  if not prompt: prompt = ep.prompt
  if prompt:
    #Trace('waiting for prompt "%s"' % prompt)
    data = WaitForString(ep.stdout, prompt,
                         timeout=timeout, reset_on_activity=reset_on_activity)
    if data:
      # data contains everything on ep.stdout up to and including the prompt,
      # plus everything up 'til the newline.  Scrape out the prompt
      # and everything that follows, and ensure that the result ends
      # in a newline (which is important if it would otherwise be empty).
      s = data.tostring()
      i = s.rfind(prompt)
      s = s[:i]
      if s[-1:] != '\n':
        s += '\n'
      if _DEBUG_READ:
        print 'WaitForPrompt saw """\n%s"""' % s
      return s
  return None


def ReplaceEmulatorPrompt(ep, prompt=None):
  """Replaces PS1 in the emulator with a different value.

  This is useful for making the prompt unambiguous; i.e., something
  that probably won't appear in the output of another command.

  Assumes that the emulator is already sitting at a prompt,
  waiting for shell input.

  Puts the new prompt in ep.prompt.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    prompt: The new prompt to use

  Returns:
    True on success, False if the timeout occurred.
  """
  if not prompt:
    prompt = '-----DEXPREOPT-PROMPT-----'
  print >>ep.stdin, 'PS1="%s\n"' % prompt
  ep.prompt = prompt

  # Eat the command echo.
  data = WaitForPrompt(ep, timeout=2)
  if not data:
    return False

  # Make sure it's actually there.
  return WaitForPrompt(ep, timeout=2)


def RunEmulatorCommand(ep, cmd, timeout=0):
  """Sends the command to the emulator's shell and waits for the result.

  Assumes that the emulator is already sitting at a prompt,
  waiting for shell input.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    cmd: The shell command to run in the emulator.
    timeout: The number of seconds to wait for the command to complete,
             or zero for no timeout.

  Returns:
    If the command ran and returned to the console prompt before the
    timeout, returns the output of the command as a string.
    Returns None otherwise.
  """
  ConsumeAvailableData(ep.stdout)

  Trace('Running "%s"' % cmd)
  print >>ep.stdin, '%s' % cmd

  # The console will echo the command.
  #Trace('Waiting for echo')
  if WaitForString(ep.stdout, cmd, timeout=timeout):
    #Trace('Waiting for completion')
    return WaitForPrompt(ep, timeout=timeout, reset_on_activity=True)

  return None


def ReadFileList(ep, dir_list, timeout=0):
  """Returns a list of emulator files in each dir in dir_list.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    dir_list: List absolute paths to directories to read.
    timeout: The number of seconds to wait for the command to complete,
             or zero for no timeout.

  Returns:
    A list of absolute paths to files in the named directories,
    in the context of the emulator's filesystem.
    None on failure.
  """
  ret = []
  for d in dir_list:
    output = RunEmulatorCommand(ep, 'ls ' + d, timeout=timeout)
    if not output:
      Trace('Could not ls ' + d)
      return None
    ret += ['%s/%s' % (d, f) for f in output.splitlines()]
  return ret


def DownloadDirectoryHierarchy(ep, src, dest, timeout=0):
  """Recursively downloads an emulator directory to the local filesystem.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    src: The path on the emulator's filesystem to download from.
    dest: The path on the local filesystem to download to.
    timeout: The number of seconds to wait for the command to complete,
             or zero for no timeout. (CURRENTLY IGNORED)

  Returns:
    True iff the files downloaded successfully, False otherwise.
  """
  ConsumeAvailableData(ep.stdout)

  if not os.path.exists(dest):
    os.makedirs(dest)

  cmd = 'afar %s' % src
  Trace('Running "%s"' % cmd)
  print >>ep.stdin, '%s' % cmd

  # The console will echo the command.
  #Trace('Waiting for echo')
  if not WaitForString(ep.stdout, cmd, timeout=timeout):
    return False

  #TODO: use a signal to support timing out?

  #
  # Android File Archive format:
  #
  # magic[5]: 'A' 'F' 'A' 'R' '\n'
  # version[4]: 0x00 0x00 0x00 0x01
  # for each file:
  #     file magic[4]: 'F' 'I' 'L' 'E'
  #     namelen[4]: Length of file name, including NUL byte (big-endian)
  #     name[*]: NUL-terminated file name
  #     datalen[4]: Length of file (big-endian)
  #     data[*]: Unencoded file data
  #     adler32[4]: adler32 of the unencoded file data (big-endian)
  #     file end magic[4]: 'f' 'i' 'l' 'e'
  # end magic[4]: 'E' 'N' 'D' 0x00
  #

  # Read the header.
  HEADER = array.array('B', 'AFAR\n\000\000\000\001')
  buf = array.array('B')
  buf.fromfile(ep.stdout, len(HEADER))
  if buf != HEADER:
    Trace('Header does not match: "%s"' % buf)
    return False

  # Read the file entries.
  FILE_START = array.array('B', 'FILE')
  FILE_END = array.array('B', 'file')
  END = array.array('B', 'END\000')
  while True:
    # Entry magic.
    buf = array.array('B')
    buf.fromfile(ep.stdout, 4)
    if buf == FILE_START:
      # Name length (4 bytes, big endian)
      buf = array.array('B')
      buf.fromfile(ep.stdout, 4)
      (name_len,) = struct.unpack('>I', buf)
      #Trace('name len %d' % name_len)

      # Name, NUL-terminated.
      buf = array.array('B')
      buf.fromfile(ep.stdout, name_len)
      buf.pop()  # Remove trailing NUL byte.
      file_name = buf.tostring()
      Trace('FILE: %s' % file_name)

      # File length (4 bytes, big endian)
      buf = array.array('B')
      buf.fromfile(ep.stdout, 4)
      (file_len,) = struct.unpack('>I', buf)

      # File data.
      data = array.array('B')
      data.fromfile(ep.stdout, file_len)
      #Trace('FILE: read %d bytes from %s' % (file_len, file_name))

      # adler32 (4 bytes, big endian)
      buf = array.array('B')
      buf.fromfile(ep.stdout, 4)
      (adler32,) = struct.unpack('>i', buf)  # adler32 wants a signed int ('i')
      data_adler32 = zlib.adler32(data)
      if adler32 != data_adler32:
        Trace('adler32 does not match: calculated 0x%08x != expected 0x%08x' %
              (data_adler32, adler32))
        return False

      # File end magic.
      buf = array.array('B')
      buf.fromfile(ep.stdout, 4)
      if buf != FILE_END:
        Trace('Unexpected file end magic "%s"' % buf)
        return False

      # Write to the output file
      out_file_name = dest + '/' + file_name[len(src):]
      p = os.path.dirname(out_file_name)
      if not os.path.exists(p): os.makedirs(p)
      fo = file(out_file_name, 'w+b')
      fo.truncate(0)
      Trace('FILE: Writing %d bytes to %s' % (len(data), out_file_name))
      data.tofile(fo)
      fo.close()

    elif buf == END:
      break
    else:
      Trace('Unexpected magic "%s"' % buf)
      return False

  return WaitForPrompt(ep, timeout=timeout, reset_on_activity=True)


def ReadBootClassPath(ep, timeout=0):
  """Reads and returns the default bootclasspath as a list of files.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    timeout: The number of seconds to wait for the command to complete,
             or zero for no timeout.

  Returns:
    The bootclasspath as a list of strings.
    None on failure.
  """
  bcp = RunEmulatorCommand(ep, 'echo $BOOTCLASSPATH', timeout=timeout)
  if not bcp:
    Trace('Could not find bootclasspath')
    return None
  return bcp.strip().split(':')  # strip trailing newline


def RunDexoptOnFileList(ep, files, dest_root, move=False, timeout=0):
  """Creates the corresponding .odex file for all jar/apk files in 'files'.
  Copies the .odex file to a location under 'dest_root'.  If 'move' is True,
  the file is moved instead of copied.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    files: The list of files to optimize
    dest_root: directory to copy/move odex files to.  Must already exist.
    move: if True, move rather than copy files
    timeout: The number of seconds to wait for the command to complete,
             or zero for no timeout.

  Returns:
    True on success, False on failure.
  """
  for jar_file in files:
    if jar_file.endswith('.apk') or jar_file.endswith('.jar'):
      odex_file = jar_file[:jar_file.rfind('.')] + '.odex'
      cmd = 'dexopt-wrapper %s %s' % (jar_file, odex_file)
      if not RunEmulatorCommand(ep, cmd, timeout=timeout):
        Trace('"%s" failed' % cmd)
        return False

      # Always copy the odex file.  There's no cp(1), so we
      # cat out to the new file.
      dst_odex = dest_root + odex_file
      cmd = 'cat %s > %s' % (odex_file, dst_odex)  # no cp(1)
      if not RunEmulatorCommand(ep, cmd, timeout=timeout):
        Trace('"%s" failed' % cmd)
        return False

      # Move it if we're asked to.  We can't use mv(1) because
      # the files tend to move between filesystems.
      if move:
        cmd = 'rm %s' % odex_file
        if not RunEmulatorCommand(ep, cmd, timeout=timeout):
          Trace('"%s" failed' % cmd)
          return False
  return True


def InstallCacheFiles(cache_system_dir, out_system_dir):
  """Install files in cache_system_dir to the proper places in out_system_dir.

  cache_system_dir contains various files from /system, plus .odex files
  for most of the .apk/.jar files that live there.
  This function copies each .odex file from the cache dir to the output dir
  and removes "classes.dex" from each appropriate .jar/.apk.

  E.g., <cache_system_dir>/app/NotePad.odex would be copied to
  <out_system_dir>/app/NotePad.odex, and <out_system_dir>/app/NotePad.apk
  would have its classes.dex file removed.

  Args:
    cache_system_dir: The directory containing the cache files scraped from
                      the emulator.
    out_system_dir: The local directory that corresponds to "/system"
                    on the device filesystem. (the root of system.img)

  Returns:
    True if everything succeeded, False if any problems occurred.
  """
  # First, walk through cache_system_dir and copy every .odex file
  # over to out_system_dir, ensuring that the destination directory
  # contains the corresponding source file.
  for root, dirs, files in os.walk(cache_system_dir):
    for name in files:
      if name.endswith('.odex'):
        odex_file = os.path.join(root, name)

        # Find the path to the .odex file's source apk/jar file.
        out_stem = odex_file[len(cache_system_dir):odex_file.rfind('.')]
        out_stem = out_system_dir + out_stem;
        jar_file = out_stem + '.jar'
        if not os.path.exists(jar_file):
          jar_file = out_stem + '.apk'
        if not os.path.exists(jar_file):
          Trace('Cannot find source .jar/.apk for %s: %s' %
                (odex_file, out_stem + '.{jar,apk}'))
          return False

        # Copy the cache file next to the source file.
        cmd = ['cp', odex_file, out_stem + '.odex']
        ret = subprocess.call(cmd)
        if ret:  # non-zero exit status
          Trace('%s failed' % ' '.join(cmd))
          return False

  # Walk through the output /system directory, making sure
  # that every .jar/.apk has an odex file.  While we do this,
  # remove the classes.dex entry from each source archive.
  for root, dirs, files in os.walk(out_system_dir):
    for name in files:
      if name.endswith('.apk') or name.endswith('.jar'):
        jar_file = os.path.join(root, name)
        odex_file = jar_file[:jar_file.rfind('.')] + '.odex'
        if not os.path.exists(odex_file):
          if root.endswith('/system/app') or root.endswith('/system/framework'):
            Trace('jar/apk %s has no .odex file %s' % (jar_file, odex_file))
            return False
          else:
            continue

        # Attempting to dexopt a jar with no classes.dex currently
        # creates a 40-byte odex file.
        # TODO: use a more reliable check
        if os.path.getsize(odex_file) > 100:
          # Remove classes.dex from the .jar file.
          cmd = ['zip', '-dq', jar_file, 'classes.dex']
          ret = subprocess.call(cmd)
          if ret:  # non-zero exit status
            Trace('"%s" failed' % ' '.join(cmd))
            return False
        else:
          # Some of the apk files don't contain any code.
          if not name.endswith('.apk'):
            Trace('%s has a zero-length odex file' % jar_file)
            return False
          cmd = ['rm', odex_file]
          ret = subprocess.call(cmd)
          if ret:  # non-zero exit status
            Trace('"%s" failed' % ' '.join(cmd))
            return False

  return True


def KillChildProcess(p, sig=signal.SIGTERM, timeout=0):
  """Waits for a child process to die without getting stuck in wait().

  After Jean Brouwers's 2004 post to python-list.

  Args:
    p: A subprocess.Popen representing the child process to kill.
    sig: The signal to send to the child process.
    timeout: How many seconds to wait for the child process to die.
             If zero, do not time out.

  Returns:
    The exit status of the child process, if it was successfully killed.
    The final value of p.returncode if it wasn't.
  """
  os.kill(p.pid, sig)
  if timeout > 0:
    while p.poll() < 0:
      if timeout > 0.5:
        timeout -= 0.25
        time.sleep(0.25)
      else:
        os.kill(p.pid, signal.SIGKILL)
        time.sleep(0.5)
        p.poll()
        break
  else:
    p.wait()
  return p.returncode


def Trace(msg):
  """Prints a message to stdout.

  Args:
    msg: The message to print.
  """
  #print 'dexpreopt: %s' % msg
  when = datetime.datetime.now()
  print '%02d:%02d.%d  dexpreopt: %s' % (when.minute, when.second, when.microsecond, msg)


def KillEmulator():
  """Attempts to kill the emulator process, if it is running.

  Returns:
    The exit status of the emulator process, or None if the emulator
    was not running or was unable to be killed.
  """
  global _emulator_popen
  if _emulator_popen:
    Trace('Killing emulator')
    try:
      ret = KillChildProcess(_emulator_popen, sig=signal.SIGINT, timeout=5)
    except OSError:
      Trace('Could not kill emulator')
      ret = None
    _emulator_popen = None
    return ret
  return None


def Fail(msg=None):
  """Prints an error and causes the process to exit.

  Args:
    msg: Additional error string to print (optional).

  Returns:
    Does not return.
  """
  s = 'dexpreopt: ERROR'
  if msg: s += ': %s' % msg
  print >>sys.stderr, msg
  KillEmulator()
  sys.exit(1)


def PrintUsage(msg=None):
  """Prints commandline usage information for the tool and exits with an error.

  Args:
    msg: Additional string to print (optional).

  Returns:
    Does not return.
  """
  if msg:
    print >>sys.stderr, 'dexpreopt: %s', msg
  print >>sys.stderr, """Usage: dexpreopt <options>
Required options:
    -kernel <kernel file>         Kernel to use when running the emulator
    -ramdisk <ramdisk.img file>   Ramdisk to use when running the emulator
    -image <system.img file>      System image to use when running the
                                      emulator.  /system/app should contain the
                                      .apk files to optimize, and any required
                                      bootclasspath libraries must be present
                                      in the correct locations.
    -system <path>                The product directory, which usually contains
                                      files like 'system.img' (files other than
                                      the kernel in that directory won't
                                      be used)
    -outsystemdir <path>          A fully-populated /system directory, ready
                                      to be modified to contain the optimized
                                      files.  The appropriate .jar/.apk files
                                      will be stripped of their classes.dex
                                      entries, and the optimized .dex files
                                      will be added alongside the packages
                                      that they came from.
Optional:
    -tmpdir <path>                If specified, use this directory for
                                      intermediate objects.  If not specified,
                                      a unique directory under the system
                                      temp dir is used.
  """
  sys.exit(2)


def ParseArgs(argv):
  """Parses commandline arguments.

  Args:
    argv: A list of arguments; typically sys.argv[1:]

  Returns:
    A tuple containing two dictionaries; the first contains arguments
    that will be passsed to the emulator, and the second contains other
    arguments.
  """
  parser = optparse.OptionParser()

  parser.add_option('--kernel', help='Passed to emulator')
  parser.add_option('--ramdisk', help='Passed to emulator')
  parser.add_option('--image', help='Passed to emulator')
  parser.add_option('--system', help='Passed to emulator')
  parser.add_option('--outsystemdir', help='Destination /system directory')
  parser.add_option('--tmpdir', help='Optional temp directory to use')

  options, args = parser.parse_args(args=argv)
  if args: PrintUsage()

  emulator_args = {}
  other_args = {}
  if options.kernel: emulator_args['kernel'] = options.kernel
  if options.ramdisk: emulator_args['ramdisk'] = options.ramdisk
  if options.image: emulator_args['image'] = options.image
  if options.system: emulator_args['system'] = options.system
  if options.outsystemdir: other_args['outsystemdir'] = options.outsystemdir
  if options.tmpdir: other_args['tmpdir'] = options.tmpdir

  return (emulator_args, other_args)


def DexoptEverything(ep, dest_root):
  """Logic for finding and dexopting files in the necessary order.

  Args:
    ep: A subprocess.Popen object referring to the emulator process.
    dest_root: directory to copy/move odex files to

  Returns:
    True on success, False on failure.
  """
  _extra_tests = False
  if _extra_tests:
    if not RunEmulatorCommand(ep, 'ls /system/app', timeout=5):
      Fail('Could not ls')

  # We're very short on space, so remove a bunch of big stuff that we
  # don't need.
  cmd = 'rm -r /system/sounds /system/media /system/fonts /system/xbin'
  if not RunEmulatorCommand(ep, cmd, timeout=40):
    Trace('"%s" failed' % cmd)
    return False

  Trace('Read file list')
  jar_dirs = ['/system/framework', '/system/app']
  files = ReadFileList(ep, jar_dirs, timeout=5)
  if not files:
    Fail('Could not list files in %s' % ' '.join(jar_dirs))
  #Trace('File list:\n"""\n%s\n"""' % '\n'.join(files))

  bcp = ReadBootClassPath(ep, timeout=2)
  if not files:
    Fail('Could not sort by bootclasspath')

  # Remove bootclasspath entries from the main file list.
  for jar in bcp:
    try:
      files.remove(jar)
    except ValueError:
      Trace('File list does not contain bootclasspath entry "%s"' % jar)
      return False

  # Create the destination directories.
  for d in ['', '/system'] + jar_dirs:
    cmd = 'mkdir %s%s' % (dest_root, d)
    if not RunEmulatorCommand(ep, cmd, timeout=4):
      Trace('"%s" failed' % cmd)
      return False

  # First, dexopt the bootclasspath.  Keep their cache files in place.
  Trace('Dexopt %d bootclasspath files' % len(bcp))
  if not RunDexoptOnFileList(ep, bcp, dest_root, timeout=120):
    Trace('Could not dexopt bootclasspath')
    return False

  # dexopt the rest.  To avoid running out of space on the emulator
  # volume, move each cache file after it's been created.
  Trace('Dexopt %d files' % len(files))
  if not RunDexoptOnFileList(ep, files, dest_root, move=True, timeout=120):
    Trace('Could not dexopt files')
    return False

  if _extra_tests:
    if not RunEmulatorCommand(ep, 'ls /system/app', timeout=5):
      Fail('Could not ls')

  return True



def MainInternal():
  """Main function that can be wrapped in a try block.

  Returns:
    Nothing.
  """
  emulator_args, other_args = ParseArgs(sys.argv[1:])

  tmp_dir = EnsureTempDir(other_args.get('tmpdir'))
  if not tmp_dir: Fail('Could not create temp dir')

  Trace('Creating data image')
  userdata = '%s/data.img' % tmp_dir
  if not CreateZeroedFile(userdata, 32 * 1024 * 1024):
    Fail('Could not create data image file')
  emulator_args['userdata'] = userdata

  ep = StartEmulator(**emulator_args)
  if not ep: Fail('Could not start emulator')
  global _emulator_popen
  _emulator_popen = ep

  # TODO: unlink the big userdata file now, since the emulator
  # has it open.

  if not WaitForEmulator(ep, timeout=20): Fail('Emulator did not respond')
  if not ReplaceEmulatorPrompt(ep): Fail('Could not replace prompt')

  dest_root = '/data/dexpreopt-root'
  if not DexoptEverything(ep, dest_root): Fail('Could not dexopt files')

  # Grab the odex files that were left in dest_root.
  cache_system_dir = tmp_dir + '/cache-system'
  if not DownloadDirectoryHierarchy(ep, dest_root + '/system',
                                    cache_system_dir,
                                    timeout=20):
    Fail('Could not download %s/system from emulator' % dest_root)

  if not InstallCacheFiles(cache_system_dir=cache_system_dir,
                           out_system_dir=other_args['outsystemdir']):
    Fail('Could not install files')

  Trace('dexpreopt successful')
  # Success!


def main():
  try:
    MainInternal()
  finally:
    KillEmulator()


if __name__ == '__main__':
  main()
