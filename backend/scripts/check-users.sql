SELECT u.id, u."phoneNumber", u."passwordHash" IS NOT NULL as has_pw, length(u."passwordHash") as pw_len
FROM users u
WHERE u."phoneNumber" = '+251939175599';
