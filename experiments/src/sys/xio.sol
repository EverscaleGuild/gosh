pragma ton-solidity >= 0.58.0;

import "str.sol";
import "stypes.sol";
import "io.sol";
import "sbuf.sol";
/*struct s_of {
    uint attr;
    uint16 flags;
    uint16 file;
    string path;
    uint32 offset;
    bytes buf;
}*/

/*struct s_stat {
    uint16 st_dev;      // ID of device containing file
    uint16 st_ino;      // Inode number
    uint16 st_mode;     // File type and mode
    uint16 st_nlink;    // Number of hard links
    uint16 st_uid;      // User ID of owner
    uint16 st_gid;      // Group ID of owner
    uint16 st_rdev;     // Device ID (if special file)
    uint32 st_size;     // Total size, in bytes
    uint16 st_blksize;  // Block size for filesystem I/O
    uint16 st_blocks;   // Number of 512B blocks allocated
    uint32 st_mtim;     // Time of last modification
    uint32 st_ctim;     // Time of last status change
}*/

/*struct s_file {
    uint32 p;       // (*) current position in (some) buffer
    uint16 flags;   // (*) flags, below; this FILE is free if 0
    uint16 file;    // (*) fileno, if Unix descriptor, else -1
    uint16 blksize; // stat.st_blksize (may be != _bf._size) files get aligned to block boundaries on fseek()
    uint32 offset;  // current lseek offset
}*/

library xio {

    using str for string;
    using sbuf for s_sbuf;

    uint16 constant BUFSIZ  = 1024;   // size of buffer used by setbuf
    int16 constant EOF = -1;
    uint16 constant FOPEN_MAX = 20; // must be <= OPEN_MAX <sys/syslimits.h>
    uint16 constant FILENAME_MAX = 1024; // must be <= PATH_MAX <sys/syslimits.h>
    string constant P_tmpdir = "/tmp/";
    uint16 constant L_tmpnam = 1024; // XXX must be == PATH_MAX
    uint32 constant TMP_MAX = 0xFFFFFFFF;//308915776;

    /*uint16 constant SEEK_SET = 0; // set file offset to offset
    uint16 constant SEEK_CUR = 1; // set file offset to current plus offset
    uint16 constant SEEK_END = 2; // set file offset to EOF plus offset*/

    uint16 constant STDIN_FILENO = 0;
    uint16 constant STDOUT_FILENO = 1;
    uint16 constant STDERR_FILENO = 2;

    uint16 constant L_cuserid = 17;  // size for cuserid(3); MAXLOGNAME, legacy
    uint16 constant L_ctermid = 1024;// size for ctermid(3); PATH_MAX

    /*uint16 constant O_RDONLY    = 0;
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
    uint16 constant FASYNC      = 32768;*/

    function att(s_stat sst) internal returns (uint) {
        (uint16 st_dev, uint16 st_ino, uint16 st_mode, uint16 st_nlink, uint16 st_uid, uint16 st_gid, uint16 st_rdev, uint32 st_size, uint16 st_blksize,
            uint16 st_blocks, uint32 st_mtim, uint32 st_ctim) = sst.unpack();
        return (uint(st_dev) << 224) + (uint(st_ino) << 208) + (uint(st_mode) << 192) + (uint(st_nlink) << 176) + (uint(st_uid) << 160) + (uint(st_gid) << 144) +
            (uint(st_rdev) << 128) + (uint(st_size) << 96) + (uint(st_blksize) << 80) + (uint(st_blocks) << 64) + (uint(st_mtim) << 32) + st_ctim;
    }

    function st(uint val) internal returns (s_stat) {
        (uint16 st_dev, uint16 st_ino, uint16 st_mode, uint16 st_nlink, uint16 st_uid, uint16 st_gid, uint16 st_rdev, uint32 st_size, uint16 st_blksize,
            uint16 st_blocks, uint32 st_mtim, uint32 st_ctim) = (uint16(val >> 224 & 0xFFFF), uint16(val >> 208 & 0xFFFF), uint16(val >> 192 & 0xFFFF),
                uint16(val >> 176 & 0xFFFF), uint16(val >> 160 & 0xFFFF), uint16(val >> 144 & 0xFFFF), uint16(val >> 128 & 0xFFFF), uint32(val >> 96 & 0xFFFFFFFF),
                uint16(val >> 80 & 0xFFFF), uint16(val >> 64 & 0xFFFF), uint32(val >> 32 & 0xFFFFFFFF), uint32(val & 0xFFFFFFFF));
        return s_stat(st_dev, st_ino, st_mode, st_nlink, st_uid, st_gid, st_rdev, st_size, st_blksize, st_blocks, st_mtim, st_ctim);
    }

    function aread(s_of f, uint32 nbytes) internal returns (bytes) {
        uint32 offset = f.offset;
        uint32 file_len = st(f.attr).st_size;
        uint32 cap = nbytes > 0 ? math.min(nbytes, file_len - offset) : file_len - offset;
        f.offset += cap;
        if (f.offset >= file_len)
            f.flags |= io.SEOF;
        return string(f.buf.buf).substr(offset, cap);
    }

    function awrite(s_of f, bytes buf, uint32 nbytes) internal returns (s_of) {
        f.buf.buf.append(string(buf).substr(0, nbytes));
        return f;
    }

    function mode_to_flags(string mode) internal returns (uint16 flags) {
        if (mode == "r" || mode == "rb")
            flags |= io.O_RDONLY;
        if (mode == "w" || mode == "wb")
            flags |= io.O_WRONLY;
        if (mode == "a" || mode == "ab")
            flags |= io.O_APPEND;
        if (mode == "r+" || mode == "rb+" || mode == "r+b")
            flags |= io.O_RDWR;
        if (mode == "w+" || mode == "wb+" || mode == "w+b")
            //Truncate to zero length or create file for update.
            flags |= io.O_TRUNC | io.O_CREAT;
        if (mode == "a+" || mode == "ab+" || mode == "a+b")
            // Append; open or create file for update, writing at end-of-file.
            flags |= io.O_APPEND | io.O_CREAT;
    }

    function clearerr(s_of f) internal {
        f.flags &= ~io.SEOF;
        f.flags &= ~io.SERR;
    }

    function fclose(s_of f) internal {
        f.flags &= ~io.SRD;
        f.flags &= ~io.SWR;
        f.flags &= ~io.SRW;
        f.file = 0;
    }

    function feof(s_of f) internal returns (bool) {
        return (f.flags & io.SEOF) > 0;
    }

    function ferror(s_of f) internal returns (bool) {
        return (f.flags & io.SERR) > 0;
    }

    function fflush(s_of f) internal returns (bytes) {

    }
    function fgetc(s_of f) internal returns (bytes) {
        return aread(f, 1);
    }

    function fgetpos(s_of f) internal returns (uint32) {
        return f.offset;
    }

    function fgets(s_of f, uint32 size) internal returns (bytes) {
        return aread(f, size);
    }

    /*function fopen(s_of[] dfs, string filename, string mode) internal returns (s_of) {
        for (uint i = 0; i < dfs.length; i++) {
            s_of f = dfs[i];
            if (f.path == filename) {
                f.flags = mode_to_flags(mode);
            }
        }
    }*/

    function fputc(s_of f, byte c) internal {
        /*bytes buf;
        buf[0] = c;
        awrite(f, buf, 1);*/
        s_sbuf s = f.buf;
        s.sbuf_putc(c);
        f.buf = s;
        f.offset = s.sbuf_len();
    }

    function fputs(s_of f, string str) internal {
        s_sbuf s = f.buf;
        s.sbuf_cat(str);
        s.sbuf_nl_terminate();
        f.buf = s;
        f.offset = s.sbuf_len();
//        awrite(f, s, s.byteLength());
    }
    function fread(s_of f, uint16 size, uint16 nmemb) internal returns (bytes) {
        return aread(f, size * nmemb);
    }

    function freopen(s_of stream, string path, string mode) internal {

    }

    function fseek(s_of stream, uint32 offset, uint8 whence) internal {
        uint32 pos;
        if (whence == io.SEEK_SET)
            pos = offset;
        else if (whence == io.SEEK_CUR)
            pos = pos + stream.offset;
        else if (whence == io.SEEK_END)
            pos = stream.offset;
    }

    function fsetpos(s_of f, uint32 pos) internal {
        f.offset = pos;
    }

    function ftell(s_of f) internal returns (uint32) {
        return f.offset;
    }

    function fwrite(s_of f, bytes ptr, uint16 size, uint16 nmemb) internal {
        awrite(f, ptr, size * nmemb);
    }

    function getc(s_of f) internal returns (bytes) {
        return aread(f, 1);
    }

    function gets_s(s_of f, uint32 size) internal returns (bytes) {
        return aread(f, size);
    }

//    function remove(string) internal returns (s_aiocb cb) {}
//    function rename(string from, string to) internal returns (s_aiocb cb) {}

    function rewind(s_of f) internal {
        f.offset = 0;
        clearerr(f);
    }

//    function setbuf(s_file stream, string) internal {}
    function tmpfile() internal returns (s_of stream) {}

    function tmpnam() internal returns (string) {

    }
//    function ctermid(string) internal returns (uint16) {}

    function fileno(s_of f) internal returns (uint16) {
        return f.file;
    }

    function pclose(s_of stream) internal returns (uint8) {
    }

    function popen(string cmd, string mode) internal returns (s_of stream) {

    }

    function getw(s_of f) internal returns (bytes) {
        return aread(f, 2);
    }

    function split(s_of f) internal returns (string[] fields, uint n_fields) {
        uint len = st(f.attr).st_size;
        string text = f.buf.buf;
        if (len > 0) {
            uint prev;
            uint cur;
            while (cur < len) {
                if (text.substr(cur, 1) == "\n") {
                    fields.push(text.substr(prev, cur - prev));
                    prev = cur + 1;
                }
                cur++;
            }
            string stail = text.substr(prev);
            if (!stail.empty() && stail != "\n")
                fields.push(stail);
            n_fields = fields.length;
        }
    }

//    function tempnam(string, string) internal returns (uint16) {}
    //function fmemopen(void * __restrict, size_t, string) internal returns (FILE) {}
//    function getdelim(string, uint32, byte, s_file stream) internal returns (s_aiocb) {}
//    function open_memstream(string, uint32) internal returns (s_file stream) {}
//    function renameat(int, string, int, string) internal returns (int) {}

    function getline(s_of f) internal returns (string) {
        uint pos = f.offset;
        string buf = f.buf.buf;
        string tail = buf.substr(pos);
        uint p = tail.strchr("\n");

        uint32 file_len = st(f.attr).st_size;

        if (p > 0) {
            f.offset += uint32(p);
            if (f.offset >= file_len)
                f.flags |= io.SEOF;
            return tail.substr(0, p - 1);
        }
        f.flags |= io.SEOF;
        f.offset = file_len;
        return tail;
    }

    function ctermid_r(string) internal returns (uint16) {}
    function fcloseall() internal {}
    function fdclose(s_of stream, uint16) internal returns (int) {}

    function fgetln(s_of f) internal returns (string) {
        uint pos = f.offset;
        string buf = f.buf.buf;
        string tail = buf.substr(pos);
        uint p = tail.strchr("\n");
        uint32 file_len = st(f.attr).st_size;

        if (p > 0) {
            f.offset += uint32(p);
            if (f.offset >= file_len)
                f.flags |= io.SEOF;
            return tail.substr(0, p);
        }
        f.flags |= io.SEOF;
        f.offset = file_len;
        return tail;
    }

//    function fpurge(s_file stream) internal returns (s_aiocb) {}

// The system error table contains messages for the first sys_nerr positive errno values.
// Use strerror() or strerror_r() from <string.h> instead
//extern const int sys_nerr;
//extern const char * const sys_errlist[];

}