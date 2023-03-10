CREATE TABLE `User` (
  `UserID` bigint unsigned NOT NULL AUTO_INCREMENT,
  `UserGUID` varchar(50) DEFAULT NULL,
  `UserType` tinyint unsigned DEFAULT NULL COMMENT '1:SuperAdmin, 2:Business Admin, 3:Restaurant User, 4:Vendor User',
  `FirstName` varchar(100) DEFAULT NULL,
  `LastName` varchar(100) DEFAULT NULL,
  `ContactID` bigint unsigned DEFAULT NULL,
  `Email` varchar(200) DEFAULT NULL,
  `ProfileImage` varchar(200) DEFAULT NULL,
  `CreatedBy` bigint unsigned DEFAULT NULL,
  `CreatedOn` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `EditedBy` bigint unsigned DEFAULT NULL,
  `EditedOn` timestamp NULL DEFAULT NULL,
  `IsDeleted` tinyint(1) DEFAULT '0',
  `IsActive` tinyint(1) DEFAULT '0',
  `LastLoginOn` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`UserID`),
  KEY `FK_User_Contact` (`ContactID`),
  KEY `IDX_User_UserGUID` (`UserGUID`),
  CONSTRAINT `FK_User_Contact` FOREIGN KEY (`ContactID`) REFERENCES `Contact` (`ContactID`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
