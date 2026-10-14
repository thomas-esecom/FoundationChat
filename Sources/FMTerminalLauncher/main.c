#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

// Foundation's Process may create a process group. Join the parent's group before
// setsid(), then attach the inherited PTY as the controlling terminal for fm's TUI.
int main(int argc, char **argv) {
    if (getsid(0) != getpid()) {
        if (getpgrp() == getpid() && setpgid(0, getpgid(getppid())) == -1) {
            perror("fm terminal: setpgid");
            return 1;
        }
        if (setsid() == -1) {
            perror("fm terminal: setsid");
            return 1;
        }
    }
    if (ioctl(STDIN_FILENO, TIOCSCTTY, 0) == -1 || tcsetpgrp(STDIN_FILENO, getpgrp()) == -1) {
        perror("fm terminal: controlling terminal");
        return 1;
    }
    if (argc > 3 || (argc == 2 && strcmp(argv[1], "--continue") != 0) ||
        (argc == 3 && (strcmp(argv[1], "--resume") != 0 || !argv[2][0] ||
         strcmp(argv[2], ".") == 0 || strcmp(argv[2], "..") == 0 ||
         strchr(argv[2], '/') || strchr(argv[2], '\\')))) {
        fprintf(stderr, "fm terminal: unsupported argument\n");
        return 1;
    }
    char *arguments[] = {"fm", "chat", "--model", "system", argc >= 2 ? argv[1] : NULL, argc == 3 ? argv[2] : NULL, NULL};
    execv("/usr/bin/fm", arguments);
    perror("fm terminal: execv");
    return 1;
}
