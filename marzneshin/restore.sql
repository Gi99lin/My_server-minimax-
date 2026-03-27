-- Отключаем проверку ключей на время очистки таблиц
SET FOREIGN_KEY_CHECKS = 0;

-- Очищаем таблицы перед вставкой
TRUNCATE TABLE hosts;
TRUNCATE TABLE inbounds;

-- Включаем проверку обратно
SET FOREIGN_KEY_CHECKS = 1;

-- 1. Добавляем 2 Inbound-а (VLESS Reality и Hysteria2)
INSERT INTO inbounds (id, protocol, tag, config) VALUES 
(1, 'VLESS', 'VLESS TCP REALITY', '{"tag": "VLESS TCP REALITY", "port": 443, "listen": "::", "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}, "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {"show": false, "dest": "www.google.com:443", "xver": 0, "serverNames": ["www.google.com"], "privateKey": "aD6j_Ti6aWHFepe5ZcaSCplOxqnjJNGmVa-miTW3wHo", "shortIds": ["99d1ee3d8620a069", "cd2d6dbc", "8051"]}}}'),
(2, 'Hysteria2', 'Hysteria2', '{"type": "hysteria2", "tag": "Hysteria2", "listen": "::", "listen_port": 10443, "up_mbps": 1000, "down_mbps": 1000, "obfs": {"type": "salamander", "password": "uETBP6tUHVT9i095Eqnam_ZMHI2L37Pj"}, "tls": {"enabled": true, "server_name": "home.gigglin.tech", "certificate_path": "/var/lib/marznode/hysteria.cert", "key_path": "/var/lib/marznode/hysteria.key"}}');

-- 2. Добавляем хосты для VLESS (ссылаемся на inbound_id = 1). Поля fragment и udp_noises ожидают JSON (json_valid).
INSERT INTO hosts (remark, address, port, sni, fingerprint, fragment, udp_noises, inbound_id, security) VALUES 
('THE.FI (VLESS)', '185.231.206.53', 443, 'www.helsinki.fi', 'chrome', '"tlshello,100-200,10-20"', '"rand,10-20,10-15"', 1, 'inbound_default'),
('THE.LU (VLESS)', '45.12.139.177', 443, 'www.booking.com', 'chrome', '"tlshello,100-200,10-20"', '"rand,10-20,10-15"', 1, 'inbound_default'),
('THE.NL (VLESS)', '85.208.110.9', 443, 'www.bol.com', 'chrome', '"tlshello,100-200,10-20"', '"rand,10-20,10-15"', 1, 'inbound_default'),
('VDSina.NL (VLESS)', '194.60.132.37', 443, 'www.ns.nl', 'chrome', '"tlshello,100-200,10-20"', '"rand,10-20,10-15"', 1, 'inbound_default'),
('HOME (VLESS)', '127.0.0.1', 8443, 'www.google.com', 'chrome', '"tlshello,100-200,10-20"', '"rand,10-20,10-15"', 1, 'inbound_default');

-- 3. Добавляем хосты для Hysteria2 (ссылаемся на inbound_id = 2)
INSERT INTO hosts (remark, address, port, password, allowinsecure, inbound_id, security) VALUES 
('THE.FI (Hysteria2)', '185.231.206.53', 10443, 'E7yPj1K5CNQbq04E6HZBpD5uu5Mp1eIC', 1, 2, 'inbound_default'),
('THE.LU (Hysteria2)', '45.12.139.177', 10443, 'LFltj6ZixEhM2zQH0JofWPPaCSGSk8Hy', 1, 2, 'inbound_default'),
('THE.NL (Hysteria2)', '85.208.110.9', 10443, 'pWjNhuFZynQD2vT9rvlExsHxf_2of44t', 1, 2, 'inbound_default'),
('VDSina.NL (Hysteria2)', '194.60.132.37', 10443, 'sjMFGJGNsJiKo3xyupNC2CgSvWzXx3a-', 1, 2, 'inbound_default'),
('HOME (Hysteria2)', '127.0.0.1', 10443, 'uETBP6tUHVT9i095Eqnam_ZMHI2L37Pj', 1, 2, 'inbound_default');
