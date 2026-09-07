use File::Slurp qw(read_file);

[
    [ "server.crt" => CORE::join('', read_file('t/fixtures/server-lvh.crt')) ],
    [ "server.key" => CORE::join('', read_file('t/fixtures/server-lvh.key')) ],
    [ "client.crt" => CORE::join('', read_file('t/fixtures/client.crt')) ],
    [ "client.key" => CORE::join('', read_file('t/fixtures/client.key')) ],
    [ "passwords.file" => CORE::join('', read_file('t/fixtures/passwords.file')) ],
]
