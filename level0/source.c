#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int	main(int ac, char **av)
{
	char *args[2];
	gid_t gid;
	uid_t uid;

	if (atoi(av[1]) == 0x1a7)
	{
		args[0] = strdup("/bin/sh");
		args[1] = NULL;
		gid = getegid();
		uid = geteuid();
		setresgid(gid, gid, gid);
		setresuid(uid, uid, uid);
		execv("/bin/sh", args);
	}
	// main+152
	else
		fwrite("No !\n", sizeof(char), 5, stderr);
	return (0);
}
