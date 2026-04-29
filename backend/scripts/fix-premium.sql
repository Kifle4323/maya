SELECT c."premiumAmount", h."memberCount", h."householdCode", h."membershipType"
FROM coverages c
JOIN households h ON c."householdId" = h.id
ORDER BY c."createdAt" DESC LIMIT 5;
