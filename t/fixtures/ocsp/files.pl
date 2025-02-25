use File::Slurp qw(read_file);

[
    [ "ca.pem" => CORE::join('',
        read_file('t/fixtures/ocsp/intermediate_ca.pem'),
        read_file('t/fixtures/ocsp/ca.pem'),
    ) ],
    [ "server.pem" => CORE::join('', read_file('t/fixtures/ocsp/leaf.pem')) ],
    [ "server-key.pem" => CORE::join('', read_file('t/fixtures/ocsp/leaf-key.pem')) ],
    [ "client.pem" => CORE::join('', read_file('t/fixtures/ocsp/client.pem')) ],
    [ "client-key.pem" => CORE::join('', read_file('t/fixtures/ocsp/client-key.pem')) ],
    [ "chain.pem" => CORE::join('', read_file('t/fixtures/ocsp/chain.pem')) ],
    [ "wrong-issuer-order-chain.pem" => CORE::join('', read_file('t/fixtures/ocsp/wrong-issuer-order-chain.pem')) ],
]
