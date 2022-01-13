function connect() {
    conn = pg_connect("application_name=smtp target_session_attrs=read-write")
    if (!conn) {
        print("!pg_connect") > "/dev/stderr"
        exit 1
    }
    rcpt = pg_prepare(conn, "UPDATE email SET result[array_position(recipient, $3)] = $2 WHERE message_id = ('x'||$1)::bit(28)::int")
    if (!rcpt) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        exit 1
    }
    rollback = pg_prepare(conn, "UPDATE email SET result = array_fill('permfail'::text, array[array_length(recipient, 1)]) WHERE array_length(recipient, 1) = 1 and message_id = ('x'||$1)::bit(28)::int")
    if (!rollback) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        exit 1
    }
}
BEGIN {
    FS = "|"
    OFS = FS
    _ = FS
    connect()
}
"config|subsystem|smtp-out" == $0 {
    print("register|report|smtp-out|tx-rcpt")
    print("register|report|smtp-out|tx-rollback")
    next
}
"config|ready" == $0 {
    print("register|ready")
    fflush()
    next
}
"report|smtp-out|tx-rcpt" == $1_$4_$5 {
    val[1] = $7
    val[2] = $8
    val[3] = $9
    res = pg_execprepared(conn, rcpt, 3, val)
    if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
        connect()
        res = pg_execprepared(conn, rcpt, 3, val)
    }
    if (res != "OK 1") {
        print(pg_errormessage(conn)) > "/dev/stderr"
    }
    pg_clear(res)
    delete val
    next
}
"report|smtp-out|tx-rollback" == $1_$4_$5 {
    val[1] = $7
    res = pg_execprepared(conn, rollback, 1, val)
    if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
        connect()
        res = pg_execprepared(conn, rollback, 1, val)
    }
    if (res != "OK 1") {
        print(pg_errormessage(conn)) > "/dev/stderr"
    }
    pg_clear(res)
    delete val
    next
}
END {
    pg_disconnect(conn)
}
