pragma ton-solidity >= 0.58.0;

import "ustd.sol";
import "libstat.sol";
import "sbuf.sol";
import "xio.sol";

library io {

    using libstat for s_stat;
    using sbuf for s_sbuf;
    using xio for s_of;
    uint16 constant O_RDONLY    = 0;
    uint16 constant O_WRONLY    = 1;
    uint16 constant O_RDWR      = 2;
    uint16 constant O_ACCMODE   = 3;
    uint16 constant O_LARGEFILE = 16;
    uint16 constant O_DIRECTORY = 32;   // must be a directory
    uint16 constant O_NOFOLLOW  = 64;   // don't follow links
    uint16 constant O_CLOEXEC   = 128;  // set close_on_exec
    uint16 constant O_CREAT     = 256;
    uint16 constant O_EXCL      = 512;
    uint16 constant O_NOCTTY    = 1024;
    uint16 constant O_TRUNC     = 2048;
    uint16 constant O_APPEND    = 4096;
    uint16 constant O_NONBLOCK  = 8192;
    uint16 constant O_DSYNC     = 16384;
    uint16 constant FASYNC      = 32768;

    uint16 constant SLBF  = 0x0001; // line buffered
    uint16 constant SNBF  = 0x0002; // unbuffered
    uint16 constant SRD   = 0x0004; // OK to read
    uint16 constant SWR   = 0x0008; // OK to write. RD and WR are never simultaneously asserted
    uint16 constant SRW   = 0x0010; // open for reading & writing
    uint16 constant SEOF  = 0x0020; // found EOF
    uint16 constant SERR  = 0x0040; // found error
    uint16 constant SMBF  = 0x0080; // _bf._base is from malloc
    uint16 constant SAPP  = 0x0100; // fdopen()ed in append mode
    uint16 constant SSTR  = 0x0200; // this is an sprintf/snprintf string
    uint16 constant SOPT  = 0x0400; // do fseek() optimization
    uint16 constant SNPT  = 0x0800; // do not do fseek() optimization
    uint16 constant SOFF  = 0x1000; // set iff _offset is in fact correct
    uint16 constant SMOD  = 0x2000; // true => fgetln modified _p text
    uint16 constant SALC  = 0x4000; // allocate string space dynamically
    uint16 constant SIGN  = 0x8000; // ignore this file in _fwalk

    uint8 constant SEEK_SET = 0; // set file offset to offset
    uint8 constant SEEK_CUR = 1; // set file offset to current plus offset
    uint8 constant SEEK_END = 2; // set file offset to EOF plus offset

    uint16 constant STDIN_FILENO = 0;
    uint16 constant STDOUT_FILENO = 1;
    uint16 constant STDERR_FILENO = 2;

    uint8 constant FREAD    = 0x0001;
    uint8 constant FWRITE   = 0x0002;
    // command values
    uint8 constant F_DUPFD          = 0; // duplicate file descriptor
    uint8 constant F_GETFD          = 1; // get file descriptor flags
    uint8 constant F_SETFD          = 2; // set file descriptor flags
    uint8 constant F_GETFL          = 3; // get file status flags
    uint8 constant F_SETFL          = 4; // set file status flags
    uint8 constant F_GETOWN         = 5; // get SIGIO/SIGURG proc/pgrp
    uint8 constant F_SETOWN         = 6; // set SIGIO/SIGURG proc/pgrp
    uint8 constant F_OGETLK         = 7; // get record locking information
    uint8 constant F_OSETLK         = 8; // set record locking information
    uint8 constant F_OSETLKW        = 9; // F_SETLK; wait if blocked
    uint8 constant F_DUP2FD         = 10; // duplicate file descriptor to arg
    uint8 constant F_GETLK          = 11; // get record locking information
    uint8 constant F_SETLK          = 12; // set record locking information
    uint8 constant F_SETLKW         = 13; // F_SETLK; wait if blocked
    uint8 constant F_SETLK_REMOTE   = 14; // debugging support for remote locks
    uint8 constant F_READAHEAD      = 15; // read ahead
    uint8 constant F_RDAHEAD        = 16; // Darwin compatible read ahead
    uint8 constant F_DUPFD_CLOEXEC  = 17; // Like F_DUPFD, but FD_CLOEXEC is set
    uint8 constant F_DUP2FD_CLOEXEC = 18; // Like F_DUP2FD, but FD_CLOEXEC is set
    uint8 constant F_ADD_SEALS      = 19;
    uint8 constant F_GET_SEALS      = 20;
    uint8 constant F_ISUNIONSTACK   = 21; // Kludge for libc, don't use it.
    // Seals (F_ADD_SEALS, F_GET_SEALS).
    uint8 constant F_SEAL_SEAL      = 0x0001; // Prevent adding sealings
    uint8 constant F_SEAL_SHRINK    = 0x0002; // May not shrink
    uint8 constant F_SEAL_GROW      = 0x0004; // May not grow
    uint8 constant F_SEAL_WRITE     = 0x0008; // May not write

    // file descriptor flags (F_GETFD, F_SETFD)
    uint8 constant FD_CLOEXEC = 1; // close-on-exec flag

    // record locking flags (F_GETLK, F_SETLK, F_SETLKW)
    uint8 constant F_RDLCK      = 1; // shared or read lock
    uint8 constant F_UNLCK      = 2; // unlock
    uint8 constant F_WRLCK      = 3; // exclusive or write lock
    uint8 constant F_UNLCKSYS   = 4; // purge locks for a given system ID
    uint8 constant F_CANCEL     = 5; // cancel an async lock request

    uint8 constant F_WAIT   = 0x010; // Wait until lock is granted
    uint8 constant F_FLOCK  = 0x020; // Use flock(2) semantics for lock
    uint8 constant F_POSIX  = 0x040; // Use POSIX semantics for lock
    uint8 constant F_REMOTE = 0x080; // Lock owner is remote NFS client

    uint16 constant F_NOINTR = 0x100; // Ignore signals when waiting

    // Advice to posix_fadvise
    uint8 constant POSIX_FADV_NORMAL    = 0; // no special treatment
    uint8 constant POSIX_FADV_RANDOM    = 1; // expect random page references
    uint8 constant POSIX_FADV_SEQUENTIAL= 2; // expect sequential page references
    uint8 constant POSIX_FADV_WILLNEED  = 3; // will need these pages
    uint8 constant POSIX_FADV_DONTNEED  = 4; // dont need these pages
    uint8 constant POSIX_FADV_NOREUSE   = 5; // access data only once

    // Magic value that specify that corresponding file descriptor to filename
    //  is unknown and sanitary check should be omitted in the funlinkat() and similar syscalls.
    int8 constant FD_NONE = -100;

    function execve(s_proc p, string path, string[] argv, string[] envp) internal returns (uint16 pid) {
//        p.p_comm = argv[0];
    /*"p_args": {
      "ar_length": "0",
      "ar_args": ""
    },*/

    }

    function _mode_to_flags(string mode) internal returns (uint16 flags) {
        if (mode == "r" || mode == "rb")
            flags |= O_RDONLY;
        if (mode == "w" || mode == "wb")
            flags |= O_WRONLY;
        if (mode == "a" || mode == "ab")
            flags |= O_APPEND;
        if (mode == "r+" || mode == "rb+" || mode == "r+b")
            flags |= O_RDWR;
        if (mode == "w+" || mode == "wb+" || mode == "w+b")
            //Truncate to zero length or create file for update.
            flags |= O_TRUNC | O_CREAT;
        if (mode == "a+" || mode == "ab+" || mode == "a+b")
            // Append; open or create file for update, writing at end-of-file.
            flags |= O_APPEND | O_CREAT;
    }

    function getdirentries(s_proc p, int fd, string buf, int nbytes, uint32 basep) internal returns (s_dirent[]) {

    }
    /*function getdents(s_proc p, int fd, string buf, int nbytes) internal returns (s_dirent[]) {
        s_of[] fdt = p.p_fd.fdt_ofiles;
        uint n_files = p.p_fd.fdt_nfiles;
        for (uint i = 0; i < n_files; i++) {
            s_of f = fdt[i];
            if (f.file == fd) {
            }
        }
    }*/

    function open(s_proc p, string path, uint16 /*flags*/) internal returns (uint16) {
        s_of[] fdt = p.p_fd.fdt_ofiles;
        uint n_files = p.p_fd.fdt_nfiles;
        for (uint i = 0; i < n_files; i++) {
            s_of f = fdt[i];
            if (f.path == path) {
                s_stat st;
                st.stt(f.attr);
                if (st.st_uid == p.p_ucred.cr_uid || st.st_gid == p.p_ucred.cr_groups[0])
                    return uint16(i);
            }
        }
    }

    function _fetch(s_proc p, string path) internal returns (uint) {
        s_of[] fdt = p.p_fd.fdt_ofiles;
        uint n_files = p.p_fd.fdt_nfiles;
        for (uint i = 0; i < n_files; i++)
            if (fdt[i].path == path)
                return i + 1;
    }
//    function fopen(s_proc p, string path, uint16 flags) internal returns (s_of) {
    function fopen(s_proc p, string path, string mode) internal returns (s_of f) {
        uint16 flags = _mode_to_flags(mode);
        uint q = _fetch(p, path);
        if (q > 0) {
            f = p.p_fd.fdt_ofiles[q - 1];
            s_stat st;
            st.stt(f.attr);
            if (st.st_uid == p.p_ucred.cr_uid || st.st_gid == p.p_ucred.cr_groups[0])
                return flags > 0 ? f : f;
        }
        f.flags |= io.SERR;
    }

    function perror(s_proc p, string reason) internal {
        s_of f = p.p_fd.fdt_ofiles[STDERR_FILENO];
        string err_msg = p.p_comm + ": ";
        if (!reason.empty())
            err_msg.append(reason + " ");
        f.fputs(err_msg);
        p.p_fd.fdt_ofiles[STDERR_FILENO] = f;
    }

    function puts(s_proc p, string str) internal {
        s_of f = p.p_fd.fdt_ofiles[STDOUT_FILENO];
        f.fputs(str);
        p.p_fd.fdt_ofiles[STDOUT_FILENO] = f;
    }

    function putchar(s_proc p, byte c) internal {
        s_sbuf s = p.p_fd.fdt_ofiles[STDOUT_FILENO].buf;
        s.sbuf_putc(c);
        p.p_fd.fdt_ofiles[STDOUT_FILENO].buf = s;
    }

    function stdin(s_proc p) internal returns (s_of) {
        return p.p_fd.fdt_ofiles[STDIN_FILENO];
    }

    function stdout(s_proc p) internal returns (s_of) {
        return p.p_fd.fdt_ofiles[STDOUT_FILENO];
    }

    function stderr(s_proc p) internal returns (s_of) {
        return p.p_fd.fdt_ofiles[STDERR_FILENO];
    }

    function fcloseall(s_proc p) internal {
//        for
    }
    function fdclose(s_of stream, uint16) internal returns (int) {}

     function popen(string command, string ctype) internal returns (s_of) {
         /*bytes bts = bytes(ctype);
         if (bts[0] == 'r') {
         } else if (bts[0] == 'w') {

         }*/
        //`r' for reading, `w' for writing, or `r+' for reading and writing.

     //A letter `e' may be appended to that to request that the underlying file
     }
     function pclose(s_of stream) internal returns (uint16) {}

    function creat(string, uint16) internal returns (uint16) {}
    function fcntl(s_proc p, uint16 fd, uint8 cmd) internal returns (uint16) {


    }
    function flock(uint16, uint16) internal returns (uint16) {}
    function posix_fadvise(uint16, uint32, uint32, uint16) internal returns (uint16) {}
    function posix_fallocate(uint16, uint32, uint32) internal returns (uint16) {}
}