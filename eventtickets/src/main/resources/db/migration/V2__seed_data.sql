-- Passwords: admin / admin123, alice / user123, dara / user123 (BCrypt, cost 10)
INSERT INTO TB_USER (USR_NM, PWD, ROLE_CD, REG_DTM, MOD_DTM, REG_ID, MOD_ID) VALUES
('admin', '$2a$10$T/tlKZR84sT6.UlasQ8bA.Z06Q7QMLsU3q77SQ.0xsaX9jIxV6rzO', 'ADMIN', '20260928000000', '20260928000000', 'system', 'system'),
('alice', '$2a$10$.OyrMzpIz3tmzlqCLGTNMuZzdzIGrZBtBPwY7aXh.iUrnzPFPRBCC', 'USER',  '20260928000000', '20260928000000', 'system', 'system'),
('dara',  '$2a$10$.OyrMzpIz3tmzlqCLGTNMuZzdzIGrZBtBPwY7aXh.iUrnzPFPRBCC', 'USER',  '20260928000000', '20260928000000', 'system', 'system');

INSERT INTO TB_EVENT (EVT_NM, EVT_DTM, VENUE_NM, PRICE, TOT_SEAT, AVL_SEAT, STS_CD, REG_DTM, MOD_DTM, REG_ID, MOD_ID) VALUES
('Angkor Jazz Night',      '20261115190000', 'Chaktomuk Theatre', 25.00, 100, 100, 'ACTIVE',    '20260928000000', '20260928000000', 'system', 'system'),
('Phnom Penh Tech Summit', '20261203090000', 'Diamond Island Hall', 40.00, 5, 5,   'ACTIVE',    '20260928000000', '20260928000000', 'system', 'system'),
('Water Festival Concert', '20261120180000', 'Riverside Park',      15.00, 200, 200, 'CANCELLED', '20260928000000', '20260928000000', 'system', 'system');
