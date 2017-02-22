// Copyright (C) 2015 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// makeparallel communicates with the GNU make jobserver
// (http://make.mad-scientist.net/papers/jobserver-implementation/)
// in order claim all available jobs, and then passes the number of jobs
// claimed to a subprocess with -j<jobs>.

#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>

#include <string>
#include <vector>

#ifdef __linux__
#include <error.h>
#endif

#ifdef __APPLE__
#include <err.h>
#define error(code, eval, fmt, ...) errc(eval, code, fmt, ##__VA_ARGS__)
// Darwin does not interrupt syscalls by default.
#define TEMP_FAILURE_RETRY(exp) (exp)
#endif

// Throw an error if fd is not valid.
static void CheckFd(int fd) {
  int ret = fcntl(fd, F_GETFD);
  if (ret < 0) {
    if (errno == EBADF) {
      error(errno, 0, "no jobserver pipe, prefix recipe command with '+'");
    } else {
      error(errno, errno, "fnctl failed");
    }
  }
}

// Extract flags from MAKEFLAGS that need to be propagated to subproccess
static std::vector<std::string> ReadMakeflags() {
  std::vector<std::string> args;

  const char* makeflags_env = getenv("MAKEFLAGS");
  if (makeflags_env == nullptr) {
    return args;
  }

  // The MAKEFLAGS format is pretty useless.  The first argument might be empty
  // (starts with a leading space), or it might be a set of one-character flags
  // merged together with no leading space, or it might be a variable
  // definition.

  std::string makeflags = makeflags_env;

  // Split makeflags into individual args on spaces.  Multiple spaces are
  // elided, but an initial space will result in a blank arg.
  size_t base = 0;
  size_t found;
  do {
    found = makeflags.find_first_of(" ", base);
    args.push_back(makeflags.substr(base, found - base));
    base = found + 1;
  } while (found != makeflags.npos);

  // Drop the first argument if it is empty
  while (args.size() > 0 && args[0].size() == 0) {
	  args.erase(args.begin());
  }

  // Prepend a - to the first argument if it does not have one and is not a
  // variable definition
  if (args.size() > 0 && args[0][0] != '-') {
    if (args[0].find('=') == makeflags.npos) {
      args[0] = '-' + args[0];
    }
  }

  return args;
}

static bool ParseMakeflags(std::vector<std::string>& args,
    int* in_fd, int* out_fd, bool* parallel, bool* keep_going) {

  std::vector<char*> getopt_argv;
  // getopt starts reading at argv[1]
  getopt_argv.reserve(args.size() + 1);
  getopt_argv.push_back(strdup(""));
  for (std::string& v : args) {
    getopt_argv.push_back(strdup(v.c_str()));
  }

  opterr = 0;
  optind = 1;
  while (1) {
    const static option longopts[] = {
        {"jobserver-fds", required_argument, 0, 0},
        {0, 0, 0, 0},
    };
    int longopt_index = 0;

    int c = getopt_long(getopt_argv.size(), getopt_argv.data(), "kj",
        longopts, &longopt_index);

    if (c == -1) {
      break;
    }

    switch (c) {
    case 0:
      switch (longopt_index) {
      case 0:
      {
        // jobserver-fds
        if (sscanf(optarg, "%d,%d", in_fd, out_fd) != 2) {
          error(EXIT_FAILURE, 0, "incorrect format for --jobserver-fds: %s", optarg);
        }
        // TODO: propagate in_fd, out_fd
        break;
      }
      default:
        abort();
      }
      break;
    case 'j':
      *parallel = true;
      break;
    case 'k':
      *keep_going = true;
      break;
    case '?':
      // ignore unknown arguments
      break;
    default:
      abort();
    }
  }

  for (char *v : getopt_argv) {
    free(v);
  }

  return true;
}

// Read a single byte from fd, with timeout in milliseconds.  Returns true if
// a byte was read, false on timeout.  Throws away the read value.
// Non-reentrant, uses timer and signal handler global state, plus static
// variable to communicate with signal handler.
//
// Uses a SIGALRM timer to fire a signal after timeout_ms that will interrupt
// the read syscall if it hasn't yet completed.  If the timer fires before the
// read the read could block forever, so read from a dup'd fd and close it from
// the signal handler, which will cause the read to return EBADF if it occurs
// after the signal.
// The dup/read/close combo is very similar to the system described to avoid
// a deadlock between SIGCHLD and read at
// http://make.mad-scientist.net/papers/jobserver-implementation/
static bool ReadByteTimeout(int fd, int timeout_ms) {
  // global variable to communicate with the signal handler
  static int dup_fd = -1;

  // dup the fd so the signal handler can close it without losing the real one
  dup_fd = dup(fd);
  if (dup_fd < 0) {
    error(errno, errno, "dup failed");
  }

  // set up a signal handler that closes dup_fd on SIGALRM
  struct sigaction action = {};
  action.sa_flags = SA_SIGINFO,
  action.sa_sigaction = [](int, siginfo_t*, void*) {
    close(dup_fd);
  };
  struct sigaction oldaction = {};
  int ret = sigaction(SIGALRM, &action, &oldaction);
  if (ret < 0) {
    error(errno, errno, "sigaction failed");
  }

  // queue a SIGALRM after timeout_ms
  const struct itimerval timeout = {{}, {0, timeout_ms * 1000}};
  ret = setitimer(ITIMER_REAL, &timeout, NULL);
  if (ret < 0) {
    error(errno, errno, "setitimer failed");
  }

  // start the blocking read
  char buf;
  int read_ret = read(dup_fd, &buf, 1);
  int read_errno = errno;

  // cancel the alarm in case it hasn't fired yet
  const struct itimerval cancel = {};
  ret = setitimer(ITIMER_REAL, &cancel, NULL);
  if (ret < 0) {
    error(errno, errno, "reset setitimer failed");
  }

  // remove the signal handler
  ret = sigaction(SIGALRM, &oldaction, NULL);
  if (ret < 0) {
    error(errno, errno, "reset sigaction failed");
  }

  // clean up the dup'd fd in case the signal never fired
  close(dup_fd);
  dup_fd = -1;

  if (read_ret == 0) {
    error(EXIT_FAILURE, 0, "EOF on jobserver pipe");
  } else if (read_ret > 0) {
    return true;
  } else if (read_errno == EINTR || read_errno == EBADF) {
    return false;
  } else {
    error(read_errno, read_errno, "read failed");
  }
  abort();
}

// Measure the size of the jobserver pool by reading from in_fd until it blocks
static int GetJobserverTokens(int in_fd) {
  int tokens = 0;
  pollfd pollfds[] = {{in_fd, POLLIN, 0}};
  int ret;
  while ((ret = TEMP_FAILURE_RETRY(poll(pollfds, 1, 0))) != 0) {
    if (ret < 0) {
      error(errno, errno, "poll failed");
    } else if (pollfds[0].revents != POLLIN) {
      error(EXIT_FAILURE, 0, "unexpected event %d\n", pollfds[0].revents);
    }

    // There is probably a job token in the jobserver pipe.  There is a chance
    // another process reads it first, which would cause a blocking read to
    // block forever (or until another process put a token back in the pipe).
    // The file descriptor can't be set to O_NONBLOCK as that would affect
    // all users of the pipe, including the parent make process.
    // ReadByteTimeout emulates a non-blocking read on a !O_NONBLOCK socket
    // using a SIGALRM that fires after a short timeout.
    bool got_token = ReadByteTimeout(in_fd, 10);
    if (!got_token) {
      // No more tokens
      break;
    } else {
      tokens++;
    }
  }

  // This process implicitly gets a token, so pool size is measured size + 1
  return tokens;
}

// Return tokens to the jobserver pool.
static void PutJobserverTokens(int out_fd, int tokens) {
  // Return all the tokens to the pipe
  char buf = '+';
  for (int i = 0; i < tokens; i++) {
    int ret = TEMP_FAILURE_RETRY(write(out_fd, &buf, 1));
    if (ret < 0) {
      error(errno, errno, "write failed");
    } else if (ret == 0) {
      error(EXIT_FAILURE, 0, "EOF on jobserver pipe");
    }
  }
}

int main(int argc, char* argv[]) {
  int in_fd = -1;
  int out_fd = -1;
  bool parallel = false;
  bool keep_going = false;
  bool ninja = false;
  int tokens = 0;

  if (argc > 1 && strcmp(argv[1], "--ninja") == 0) {
    ninja = true;
    argv++;
    argc--;
  }

  if (argc < 2) {
    error(EXIT_FAILURE, 0, "expected command to run");
  }

  const char* path = argv[1];
  std::vector<char*> args({argv[1]});

  std::vector<std::string> makeflags = ReadMakeflags();
  if (ParseMakeflags(makeflags, &in_fd, &out_fd, &parallel, &keep_going)) {
    if (in_fd >= 0 && out_fd >= 0) {
      CheckFd(in_fd);
      CheckFd(out_fd);
      fcntl(in_fd, F_SETFD, FD_CLOEXEC);
      fcntl(out_fd, F_SETFD, FD_CLOEXEC);
      tokens = GetJobserverTokens(in_fd);
    }
  }

  std::string jarg;
  if (parallel) {
    if (tokens == 0) {
      if (ninja) {
        // ninja is parallel by default
        jarg = "";
      } else {
        // make -j with no argument, guess a reasonable parallelism like ninja does
        jarg = "-j" + std::to_string(sysconf(_SC_NPROCESSORS_ONLN) + 2);
      }
    } else {
      jarg = "-j" + std::to_string(tokens + 1);
    }
  }


  if (ninja) {
    if (!parallel) {
      // ninja is parallel by default, pass -j1 to disable parallelism if make wasn't parallel
      args.push_back(strdup("-j1"));
    } else {
      if (jarg != "") {
        args.push_back(strdup(jarg.c_str()));
      }
    }
    if (keep_going) {
      args.push_back(strdup("-k0"));
    }
  } else {
    if (jarg != "") {
      args.push_back(strdup(jarg.c_str()));
    }
  }

  args.insert(args.end(), &argv[2], &argv[argc]);

  args.push_back(nullptr);

  static pid_t pid;

  // Set up signal handlers to forward SIGTERM to child.
  // Assume that all other signals are sent to the entire process group,
  // and that we'll wait for our child to exit instead of handling them.
  struct sigaction action = {};
  action.sa_flags = SA_RESTART;
  action.sa_handler = [](int signal) {
    if (signal == SIGTERM && pid > 0) {
      kill(pid, signal);
    }
  };

  int ret = 0;
  if (!ret) ret = sigaction(SIGHUP, &action, NULL);
  if (!ret) ret = sigaction(SIGINT, &action, NULL);
  if (!ret) ret = sigaction(SIGQUIT, &action, NULL);
  if (!ret) ret = sigaction(SIGTERM, &action, NULL);
  if (!ret) ret = sigaction(SIGALRM, &action, NULL);
  if (ret < 0) {
    error(errno, errno, "sigaction failed");
  }

  pid = fork();
  if (pid < 0) {
    error(errno, errno, "fork failed");
  } else if (pid == 0) {
    // child
    unsetenv("MAKEFLAGS");
    unsetenv("MAKELEVEL");

    // make 3.81 sets the stack ulimit to unlimited, which may cause problems
    // for child processes
    struct rlimit rlim{};
    if (getrlimit(RLIMIT_STACK, &rlim) == 0 && rlim.rlim_cur == RLIM_INFINITY) {
      rlim.rlim_cur = 8*1024*1024;
      setrlimit(RLIMIT_STACK, &rlim);
    }

    int ret = execvp(path, args.data());
    if (ret < 0) {
      error(errno, errno, "exec %s failed", path);
    }
    abort();
  }

  // parent

  siginfo_t status = {};
  int exit_status = 0;
  ret = waitid(P_PID, pid, &status, WEXITED);
  if (ret < 0) {
    error(errno, errno, "waitpid failed");
  } else if (status.si_code == CLD_EXITED) {
    exit_status = status.si_status;
  } else {
    exit_status = -(status.si_status);
  }

  if (tokens > 0) {
    PutJobserverTokens(out_fd, tokens);
  }
  exit(exit_status);
}
