CREATE EXTENSION IF NOT EXISTS pg_curl;

CREATE TABLE email (
    id bigserial NOT NULL PRIMARY KEY,
    timestamp timestamp without time zone NOT NULL DEFAULT now(),
    subject text NOT NULL,
    sender text NOT NULL,
    recipient text[] NOT NULL,
    body text NOT NULL,
    mime bigint[],
    message_id integer,
    result text[] NOT NULL,
    referer text,
    history text[]
);

CREATE TABLE mime (
    id bigserial NOT NULL PRIMARY KEY,
    timestamp timestamp without time zone NOT NULL DEFAULT now(),
    upload text,
    data bytea NOT NULL,
    type text,
    file text,
    head text,
    code text,
    email_id bigint NOT NULL REFERENCES email (id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE email_mime (
    email_id bigint NOT NULL REFERENCES email (id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE,
    mime_id bigint NOT NULL PRIMARY KEY REFERENCES mime (id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE FUNCTION email_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$ <<local>> declare
    input text;
    recipient text;
begin
    if tg_when = 'BEFORE' then
        if tg_op = 'INSERT' or (tg_op = 'UPDATE' and new.recipient is distinct from old.recipient) then
            new.result = array_fill('new'::text, array[array_length(new.recipient, 1)]);
        end if;
    elsif tg_when = 'AFTER' then
        if tg_op = 'INSERT' then
            local.input = format($format$select send(%1$L)$format$, new.id);
            insert into task (input, plan, "group", max, timeout, delete, live) values (local.input, new.timestamp, 'send', 1, '20 sec', true, '1 hour');
        end if;
    end if;
    return case when tg_op = 'DELETE' then old else new end;
end;$_$;
CREATE TRIGGER email_after_trigger AFTER INSERT OR UPDATE OR DELETE ON email FOR EACH ROW EXECUTE PROCEDURE email_trigger();
CREATE TRIGGER email_before_trigger BEFORE INSERT OR UPDATE OR DELETE ON email FOR EACH ROW EXECUTE PROCEDURE email_trigger();

CREATE FUNCTION send(email_id bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$ <<local>> declare
    email email;
    headers text;
    mime mime;
    recipient text;
begin
    SET auto_explain.log_min_duration = 1000;
    perform curl_easy_reset();
    perform curl_easy_setopt_url('smtp://smtp:25');
    select * from email where id = send.email_id into local.email;
    foreach local.recipient in array local.email.recipient loop
        perform curl_recipient_append(local.recipient);
        perform curl_header_append('To', local.recipient);
    end loop;
    perform curl_header_append('Subject', local.email.subject);
    perform curl_header_append('From', local.email.sender);
    --perform curl_easy_setopt_mail_from(local.email.sender);
    perform curl_mime_data(local.email.body, type:='text/plain; charset=utf-8', code:='base64');
    for local.mime in select * from mime as m where m.email_id = send.email_id loop
        if local.mime.code is null then
            perform curl_mime_data(decode(encode(local.mime.data, 'escape'), 'base64'), file:='=?utf-8?B?'||encode(convert_to(local.mime.file, 'utf8'), 'base64')||'?=', type:=local.mime.type, code:='base64', head:=local.mime.head);
        else
            perform curl_mime_data(local.mime.data, file:='=?utf-8?B?'||encode(convert_to(local.mime.file, 'utf8'), 'base64')||'?=', type:=local.mime.type, code:=local.mime.code, head:=local.mime.head);
        end if;
    end loop;
    perform curl_easy_setopt_timeout(10);
    update email as e set result = array_fill('sent'::text, array[array_length(e.recipient, 1)]) where id = send.email_id;
    perform curl_easy_perform(5);
    local.headers = curl_easy_getinfo_header_in();
    begin
        update email set message_id = ('x'||(regexp_match(local.headers, E'250 2.0.0 (\\w+) Message accepted for delivery'))[1])::bit(28)::int where id = send.email_id;
        exception when others then raise warning 'ERROR: % - %', sqlstate, sqlerrm;
    end;
    return local.headers;
end;$$;
