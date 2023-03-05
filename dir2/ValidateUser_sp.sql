DROP PROCEDURE IF EXISTS `ValidateUser_sp`;
DELIMITER $$
CREATE PROCEDURE `ValidateUser_sp`(
    IN  p_Email		VARCHAR(150),
    IN  p_AppType	TINYINT,
    OUT p_ErrID   	BIGINT
)
PROC:
BEGIN
/*
*********************************************************************************************
Project/Module	    :	MADCHEF
Purpose				:	To Validate User Login    
-----------------------------------------------------------------------------------------------  
Return values       :      0 - Success   
						1000 - Unexpected Error      
						1001 - Invalid Login Email
                        1012 - Signup Not Yet Completed
                        1013 - Signup Not Yet Approved
                        1019 - Account Has Been Locked
-----------------------------------------------------------------------------------------------                 
Call syntax         : 
						CALL ValidateUser_sp('farmfreshadmin@yopmail.com',1,@p_ErrID); 
					    SELECT @p_ErrID;  

************************************************************************************************
Change History
************************************************************************************************
Date			Author				Revision    Description
------------------------------------------------------------------------------------------------
21-JAN-2022	Zco Engr						Created    
***********************************************************************************************
*/
	DECLARE l_UserID 			BIGINT UNSIGNED DEFAULT 0; 
	DECLARE l_UserType 			TINYINT;
	DECLARE l_SignupStatus 		TINYINT;
	DECLARE l_LoginPwd			VARCHAR(200);
    DECLARE l_LoginPIN			VARCHAR(6);
    DECLARE l_LoginOTP			VARCHAR(6);
    DECLARE l_LoginOTPExpiresOn	DATETIME;
    DECLARE l_IsLocked			TINYINT(1) DEFAULT 0; 
    DECLARE l_TruckID 			BIGINT UNSIGNED DEFAULT 0; 
-- -------------------------------------------------------------------------
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
    	SHOW ERRORS;
		SET p_ErrID = 1000;
	END;
-- -------------------------------------------------------------------------

	SET p_ErrID = 0;

-- 	Getting Login Info		
	SELECT UL.UserID, UL.LoginPwd, UP.PIN, UL.IsLocked, UL.LoginOTP, UL.LoginOTPExpiresOn
    INTO l_UserID, l_LoginPwd, l_LoginPIN, l_IsLocked, l_LoginOTP, l_LoginOTPExpiresOn	
	FROM UserLogin UL
    LEFT JOIN UserPIN UP ON UL.UserID = UP.UserID
	WHERE UL.UserName = p_Email	
		AND UL.IsDeleted = 0;		

--  Checking Existance Of Login    
	IF IFNULL(l_UserID,0) = 0 THEN
		SET	p_ErrID = 1001; -- Invalid Login Email
        LEAVE PROC;
	END IF;

--  Checking Wether Locked Or Not    
	IF l_IsLocked = 1 THEN
		SET	p_ErrID = 1019; -- Account Has Been Locked
        LEAVE PROC;
	END IF;
    
	SELECT UserType INTO l_UserType FROM `User` WHERE UserID = l_UserID;
	
    IF l_UserType = 3 THEN   
		SELECT TruckID INTO l_TruckID FROM `VendorDeliveryTruck` WHERE DriverUserID = l_UserID LIMIT 1;
    END IF;
    
-- 	=====================================================================================
-- 	Business Admin
-- 	=====================================================================================
	IF l_UserType = 2 THEN
		
		SELECT B.SignupStatus INTO l_SignupStatus
		FROM BusinessAdmin BA 
		JOIN Business B ON BA.BusinessID = B.BusinessID 
		WHERE BA.UserID = l_UserID;
	
		IF l_SignupStatus = 1 THEN
			SET	p_ErrID = 1012; -- Signup Not Yet Completed
			LEAVE PROC;
		END IF;
		IF l_SignupStatus = 2 THEN
			SET	p_ErrID = 1013; -- Signup Not Yet Approved
			LEAVE PROC;
		END IF;
		
	-- 	User Info
		SELECT 	U.UserID,
				U.UserGUID,
				l_LoginPwd AS LoginPwd,
                l_LoginPIN AS LoginPIN,
                l_LoginOTP AS LoginOTP,
                l_LoginOTPExpiresOn AS LoginOTPExpiresOn,
				U.FirstName,
				U.LastName,
                U.ProfileImage,
				B.BusinessType,
                B.BusinessGUID,
				U.UserType,
				NULL AS RoleID,
				NULL AS RoleName,
                NULL AS DefaultRoleID,
                C.ContactID,
	            C.CountryCode,
				C.Phone,
				C.Email,
				C.IsPhoneVerified,
				C.IsEmailVerified,
				(SELECT COUNT(NotificationID) 
					FROM Notification N 
					WHERE N.UserID = U.UserID 
						AND IsRead = 0
				)AS UnReadNotificationCount,
				(SELECT JSON_OBJECT('Permission',JSON_ARRAYAGG(P.PermissionID))
					FROM Permission P
					WHERE P.BusinessType = B.BusinessType
						AND P.AppType = p_AppType
				)AS Permissions, -- All Business Permissions
                NULL AS AssignedTruckID
		FROM `User` U
		JOIN BusinessAdmin BA ON U.UserID = BA.UserID
			AND BA.UserID = l_UserID
		JOIN Business B ON BA.BusinessID = B.BusinessID
        LEFT JOIN Contact C ON U.ContactID = C.ContactID;
	 -- Locations
		SELECT 	BL.BusinessLocationID,
				BL.LocationName,
				A.City,
                A.StateCode,
				V.VendorID,
                V.VendorGUID,
				R.RestaurantID,
                R.RestaurantGUID,
				BL.Latitude,
                BL.Longitude
		FROM BusinessAdmin BA 
		JOIN Business B ON BA.BusinessID = B.BusinessID
		JOIN BusinessLocation BL ON BA.BusinessID = BL.BusinessID
        JOIN Address A ON BL.AddressID = A.AddressID
		LEFT JOIN Vendor V ON BL.BusinessLocationID = V.BusinessLocationID
		LEFT JOIN Restaurant R ON BL.BusinessLocationID = R.BusinessLocationID
		WHERE BL.IsDeleted = 0
			AND BA.UserID = l_UserID;
			
-- 	=====================================================================================
-- 	Restaurant/Vendor User
-- 	=====================================================================================
	ELSEIF l_UserType IN(3,4) THEN   
	
	-- 	User Info
		SELECT 	U.UserID,
				U.UserGUID,
				l_LoginPwd AS LoginPwd,
                l_LoginPIN AS LoginPIN,
                l_LoginOTP AS LoginOTP,
                l_LoginOTPExpiresOn AS LoginOTPExpiresOn,
				U.FirstName,
				U.LastName,
                U.ProfileImage,
				B.BusinessType,
                B.BusinessGUID,
				U.UserType,
				BU.RoleID,
				R.RoleName,
                R.DefaultRoleID,
                C.ContactID,
	            C.CountryCode,
				C.Phone,
				C.Email,
				C.IsPhoneVerified,
				C.IsEmailVerified,
				(SELECT COUNT(NotificationID) 
					FROM Notification N 
					WHERE N.UserID = U.UserID 
						AND IsRead = 0
				)AS UnReadNotificationCount,
				(SELECT JSON_OBJECT('Permission',JSON_ARRAYAGG(RP.PermissionID))
					FROM RolePermission RP
                    JOIN Permission P ON RP.PermissionID = P.PermissionID
					WHERE RP.RoleID = BU.RoleID
						AND P.BusinessType = B.BusinessType
						AND P.AppType = p_AppType
				)AS Permissions, -- Role Specific Permissions
                l_TruckID AS AssignedTruckID
		FROM `User` U
		JOIN BusinessLocationUser BU ON U.UserID = BU.UserID
			AND BU.UserID = l_UserID     
		JOIN BusinessLocation BL ON BU.BusinessLocationID = BL.BusinessLocationID
		JOIN Business B ON BL.BusinessID = B.BusinessID
		JOIN `Role` R ON BU.RoleID = R.RoleID
		LEFT JOIN Contact C ON U.ContactID = C.ContactID;
	-- 	Locations
		SELECT 	BL.BusinessLocationID,
				BL.LocationName,
                A.City,
                A.StateCode,
				V.VendorID,
				V.VendorGUID,
				R.RestaurantID,
				R.RestaurantGUID,
				BL.Latitude,
                BL.Longitude
		FROM BusinessLocationUser BU 
		JOIN BusinessLocation BL ON BU.BusinessLocationID = BL.BusinessLocationID
        JOIN Address A ON BL.AddressID = A.AddressID
		LEFT JOIN Vendor V ON BL.BusinessLocationID = V.BusinessLocationID
		LEFT JOIN Restaurant R ON BL.BusinessLocationID = R.BusinessLocationID
		WHERE  BL.IsDeleted = 0
			AND BU.UserID = l_UserID;
	END IF;
-- 	=====================================================================================

END$$
DELIMITER ;
