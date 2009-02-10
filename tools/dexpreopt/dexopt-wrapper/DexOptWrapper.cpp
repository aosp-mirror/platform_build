/*
 * dexopt invocation test.
 *
 * You must have BOOTCLASSPATH defined.  On the simulator, you will also
 * need ANDROID_ROOT.
 */
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/file.h>
#include <fcntl.h>
#include <errno.h>

#include "cutils/properties.h"

//using namespace android;

/*
 * Privilege reduction function.
 *
 * Returns 0 on success, nonzero on failure.
 */
static int privFunc(void)
{
    printf("--- would reduce privs here\n");
    return 0;
}

/*
 * We're in the child process.  exec dexopt.
 */
static void runDexopt(int zipFd, int odexFd, const char* inputFileName)
{
    static const char* kDexOptBin = "/bin/dexopt";
    static const int kMaxIntLen = 12;   // '-'+10dig+'\0' -OR- 0x+8dig
    char zipNum[kMaxIntLen];
    char odexNum[kMaxIntLen];
    char dexoptFlags[PROPERTY_VALUE_MAX];
    const char* androidRoot;
    char* execFile;

    /* pull optional configuration tweaks out of properties */
    property_get("dalvik.vm.dexopt-flags", dexoptFlags, "");

    /* find dexopt executable; this exists for simulator compatibility */
    androidRoot = getenv("ANDROID_ROOT");
    if (androidRoot == NULL)
        androidRoot = "/system";
    execFile = (char*) malloc(strlen(androidRoot) + strlen(kDexOptBin) +1);
    sprintf(execFile, "%s%s", androidRoot, kDexOptBin);

    sprintf(zipNum, "%d", zipFd);
    sprintf(odexNum, "%d", odexFd);

    execl(execFile, execFile, "--zip", zipNum, odexNum, inputFileName,
        dexoptFlags, (char*) NULL);
    fprintf(stderr, "execl(%s) failed: %s\n", kDexOptBin, strerror(errno));
}

/*
 * Run dexopt on the specified Jar/APK.
 *
 * This uses fork() and exec() to mimic the way this would work in an
 * installer; in practice for something this simple you could just exec()
 * unless you really wanted the status messages.
 *
 * Returns 0 on success.
 */
int doStuff(const char* zipName, const char* odexName)
{
    int zipFd, odexFd;

    /*
     * Open the zip archive and the odex file, creating the latter (and
     * failing if it already exists).  This must be done while we still
     * have sufficient privileges to read the source file and create a file
     * in the target directory.  The "classes.dex" file will be extracted.
     */
    zipFd = open(zipName, O_RDONLY, 0);
    if (zipFd < 0) {
        fprintf(stderr, "Unable to open '%s': %s\n", zipName, strerror(errno));
        return 1;
    }

    odexFd = open(odexName, O_RDWR | O_CREAT | O_EXCL, 0644);
    if (odexFd < 0) {
        fprintf(stderr, "Unable to create '%s': %s\n",
            odexName, strerror(errno));
        close(zipFd);
        return 1;
    }

    printf("--- BEGIN '%s' (bootstrap=%d) ---\n", zipName, 0);

    /*
     * Fork a child process.
     */
    pid_t pid = fork();
    if (pid == 0) {
        /* child -- drop privs */
        if (privFunc() != 0)
            exit(66);

        /* lock the input file */
        if (flock(odexFd, LOCK_EX | LOCK_NB) != 0) {
            fprintf(stderr, "Unable to lock '%s': %s\n",
                odexName, strerror(errno));
            exit(65);
        }

        runDexopt(zipFd, odexFd, zipName);  /* does not return */
        exit(67);                           /* usually */
    } else {
        /* parent -- wait for child to finish */
        printf("waiting for verify+opt, pid=%d\n", (int) pid);
        int status, oldStatus;
        pid_t gotPid;

        close(zipFd);
        close(odexFd);

        /*
         * Wait for the optimization process to finish.
         */
        while (true) {
            gotPid = waitpid(pid, &status, 0);
            if (gotPid == -1 && errno == EINTR) {
                printf("waitpid interrupted, retrying\n");
            } else {
                break;
            }
        }
        if (gotPid != pid) {
            fprintf(stderr, "waitpid failed: wanted %d, got %d: %s\n",
                (int) pid, (int) gotPid, strerror(errno));
            return 1;
        }

        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            printf("--- END '%s' (success) ---\n", zipName);
            return 0;
        } else {
            printf("--- END '%s' --- status=0x%04x, process failed\n",
                zipName, status);
            return 1;
        }
    }

    /* notreached */
}

/*
 * Parse args, do stuff.
 */
int main(int argc, char** argv)
{
    if (argc < 3 || argc > 4) {
        fprintf(stderr, "Usage: %s <input jar/apk> <output odex> "
            "[<bootclasspath>]\n\n", argv[0]);
        fprintf(stderr, "Example: dexopttest "
            "/system/app/NotePad.apk /system/app/NotePad.odex\n");
        return 2;
    }

    if (argc > 3) {
        setenv("BOOTCLASSPATH", argv[3], 1);
    }

    return (doStuff(argv[1], argv[2]) != 0);
}
