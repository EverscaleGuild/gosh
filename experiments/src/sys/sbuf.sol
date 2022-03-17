pragma ton-solidity >= 0.58.0;
//import "ktypes.sol";
import "stypes.sol";
import "errno.sol";
import "str.sol";

library sbuf {

    using str for string;

    uint32 constant SBUF_FIXEDLEN   = 0x00000000; // fixed length buffer (default)
    uint32 constant SBUF_AUTOEXTEND = 0x00000001; // automatically extend buffer
    uint32 constant SBUF_INCLUDENUL = 0x00000002; // nulterm byte is counted in len
    uint32 constant SBUF_DRAINTOEOR = 0x00000004; // use section 0 as drain EOR marker
    uint32 constant SBUF_NOWAIT     = 0x00000008; // Extend with non-blocking malloc
    uint32 constant SBUF_USRFLAGMSK = 0x0000ffff; // mask of flags the user may specify
    uint32 constant SBUF_DYNAMIC    = 0x00010000; // k_buf must be freed
    uint32 constant SBUF_FINISHED   = 0x00020000; // set by sbuf_finish()
    uint32 constant SBUF_DYNSTRUCT  = 0x00080000; // sbuf must be freed
    uint32 constant SBUF_INSECTION  = 0x00100000; // set by sbuf_start_section()
    uint32 constant SBUF_DRAINATEOL = 0x00200000; // drained contents ended in \n

    uint32 constant HD_COLUMN_MASK = 0xff;
    uint32 constant HD_DELIM_MASK  = 0xff00;
    uint32 constant HD_OMIT_COUNT  = (1 << 16);
    uint32 constant HD_OMIT_HEX    = (1 << 17);
    uint32 constant HD_OMIT_CHARS  = (1 << 18);

    /*struct s_sbuf {
        bytes buf;       // storage buffer
        uint8 error;    // current error code
        uint32 size;     // size of storage buffer
        uint32 len;      // current length of string
        uint32 flags;    // flags
        uint16 sect_len; // current length of section
        uint32 rec_off;  // current record start offset
    }*/

    function sbuf_new(s_sbuf s, string buf, uint32 length, uint32 flags) internal returns (s_sbuf) {
        uint16 len = buf.strlen();
        uint8 error = len > length ? errno.ENOMEM : 0;
        s = s_sbuf(buf, error, length, len, flags, 0, 0);
        return s;
    }

    function sbuf_new_auto(s_sbuf s) internal returns (s_sbuf) {
        string empty;
        s = sbuf_new(s, empty, 0, SBUF_AUTOEXTEND);
        return s;
    }

    function sbuf_get_flags(s_sbuf s) internal returns (uint32) {
        return s.flags;
    }

    function sbuf_clear_flags(s_sbuf s, uint32 flags) internal {
        s.flags &= flags;
    }

    function sbuf_set_flags(s_sbuf s, uint32 flags) internal {
        s.flags |= flags;
    }

    function sbuf_clear(s_sbuf s) internal {
        delete s.buf;
        s.len = 0;
    }

    function sbuf_setpos(s_sbuf s, uint16 pos) internal returns (uint16) {
        if (pos < s.len)
            s.len = pos;
    }

    function sbuf_bcat(s_sbuf s, bytes buf, uint16 len) internal returns (uint16) {
        s = _add(s, buf, len, true);
    }
    function sbuf_bcpy(s_sbuf s, bytes buf, uint16 len) internal returns (uint16) {
        s = _add(s, buf, len, false);
    }
    function sbuf_cat(s_sbuf s, string ss) internal returns (uint16) {
        s = _add(s, ss, ss.strlen(), true);
    }
    function sbuf_cpy(s_sbuf s, string ss) internal returns (uint16) {
        s = _add(s, ss, ss.strlen(), false);
    }
    function sbuf_nl_terminate(s_sbuf s) internal returns (uint16) {
        if (s.len > 0 && s.buf[s.len - 1] != '\n')
            s = _add(s, '\n', 1, true);
    }
    function sbuf_putc(s_sbuf s, byte b) internal returns (uint16) {
        string str = string(s.buf) + b;
        s.buf = bytes(str);
        s.len++;
    }
    function sbuf_trim(s_sbuf s) internal returns (uint16) {
        bytes buf = s.buf;
        uint16 len = s.len;
        if (len > 0) {
            uint16 i = len;
            while (buf[i - 1] == ' ' && i > 0)
                i--;
            s.len = i;
        }
    }
    function sbuf_error(s_sbuf s) internal returns (uint16) {
        return s.error;
    }

    function sbuf_finish(s_sbuf s) internal returns (uint8) {
        if (s.len > s.size)
            s.error = errno.ENOMEM;
        s.flags |= SBUF_FINISHED;
        return s.error;
    }
    function sbuf_data(s_sbuf s) internal returns (string) {
        if ((s.flags & SBUF_FINISHED) > 0)
            return s.buf;
    }
    function sbuf_len(s_sbuf s) internal returns (uint32) {
        return s.len;
    }

    function sbuf_done(s_sbuf s) internal returns (bool) {
        return (s.flags & SBUF_FINISHED) > 0;
    }

    function sbuf_delete(s_sbuf s) internal {
        delete s;
    }

    function sbuf_start_section(s_sbuf s) internal returns (uint16 old_lenp) {
        old_lenp = s.sect_len;
        s.flags |= SBUF_INSECTION;
        s.sect_len = 0;
    }

    function sbuf_end_section(s_sbuf s, uint16 old_len, uint8 pad, byte c) internal returns (uint32) {
//        uint16 cur_len = s.sect_len;
        string padbuf;
        repeat (pad)
            padbuf = padbuf + c;
        s = _add(s, padbuf, pad, true);
        s.sect_len = old_len;
    }
    function sbuf_hexdump(s_sbuf s, bytes ptr, uint16 length, string hdr, uint16 flags) internal {

    }
    function sbuf_count_drain(bytes arg, string data, uint16 len) internal returns (uint16) {}
    function sbuf_printf_drain(bytes arg, string data, uint16 len) internal returns (uint16) {}

    function sbuf_putbuf(s_sbuf s) internal returns (bytes) {
        if ((s.flags & SBUF_FINISHED) > 0)
            return s.buf;
    }

    function _add(s_sbuf s, bytes buf, uint16 len, bool append) internal returns (s_sbuf) {
        if (append && (s.flags & SBUF_FINISHED) > 0)
            return s;
        uint16 avl = uint16(math.min(len, buf.length));
        uint16 tot = append ? avl + s.len : avl;
        uint16 cap = avl;
        if (tot > s.size) {
            if ((s.flags & SBUF_AUTOEXTEND) > 0)
                s.size = tot;
            else
                cap = uint16(s.size - s.len);
        }
        cap = math.min(cap, avl);
        if (cap > 0) {
            s.buf.append(cap < avl ? string(buf).substr(0, cap) : buf);
//            s.buf.strlcat(buf, cap);
            s.len += cap;
            if ((s.flags & SBUF_INSECTION) > 0)
                s.sect_len += cap;
        }
        return s;
    }

    function sbuf_uionew(s_sbuf s, s_uio, uint16) internal returns (s_sbuf) {

    }
    function sbuf_bcopyin(s_sbuf s, bytes uaddr, uint16 len) internal returns (uint16) {
        s = _add(s, uaddr, len, false);
    }
    function sbuf_copyin(s_sbuf s, bytes uaddr, uint16 len) internal returns (uint16) {
        s = _add(s, uaddr, len, false);
    }
}