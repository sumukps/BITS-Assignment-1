DROP PROCEDURE IF EXISTS `SaveUser_sp`;
DELIMITER $$
CREATE PROCEDURE `SaveUser_sp`
(	IN  p_UserID			BIGINT,
	IN  p_RoleID			BIGINT,
	IN  p_FirstName			VARCHAR(100),
	IN  p_LastName			VARCHAR(100),
	IN  p_Email				VARCHAR(150),
    IN 	p_CountryCode 		VARCHAR(10),
	IN  p_Phone				VARCHAR(20),
    IN  p_DefaultPwd		VARCHAR(200),
    IN  p_BusinessLocationID BIGINT,
	IN  p_LoggedinUserID	BIGINT,
	OUT p_ErrID   			BIGINT
)
PROC: 
BEGIN
/*
*********************************************************************************************
Project/Module	    :	Madchef
Purpose				:	To Create/Update User Under A Business Location
-----------------------------------------------------------------------------------------------  
Return Values       :      0 - Success   
						1000 - Unexpected Error  
                        1100 - User Already Exists Under Another BusinessLocation
                        1016 - Email Already Exists
                        1017 - Phone Already Exists
						1018 - Role Doesn't Belong To This Location
                        1052 - Only Admin User Is Allowed To Create/Modify User
-----------------------------------------------------------------------------------------------                 
Call Syntax         : 
						SET @p_UserID			= 0;
						SET @p_RoleID			= 1;
						SET @p_FirstName		= 'John';
						SET @p_LastName			= 'Doe';
						SET @p_Email			= 'someone@example.com';
                        SET @p_CountryCode		= '+1';
						SET @p_Phone			= '1234000000';
                        SET @p_p_DefaultPwd		= '$2b$10$guV6A8pBc3l6zNbJQ6KKK.tRqd.ANao6.z64no0kXakAAEY9XY5hO';
						SET @p_BusinessLocationID= 1;
                        SET @p_LoggedinUserID	 = 1;
						CALL SaveUser_sp( 	@p_UserID,@p_RoleID,@p_FirstName,@p_LastName,@p_Email,@p_CountryCode,@p_Phone,
											@p_p_DefaultPwd,@p_BusinessLocationID,@p_LoggedinUserID,@p_ErrID); 
					    SELECT @p_ErrID;  

************************************************************************************************
Change History
************************************************************************************************
Date			Author				Revision    Description
------------------------------------------------------------------------------------------------
12-FEB-2022		Zco Engr						Created    
***********************************************************************************************
*/
	DECLARE l_ContactID  	BIGINT UNSIGNED DEFAULT 0;
    DECLARE l_UserType   	TINYINT;
    DECLARE l_UserGUID   	VARCHAR(50);
    DECLARE l_DefaultRoleID  BIGINT UNSIGNED DEFAULT 0;
-- -------------------------------------------------------------------------
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
    	SHOW ERRORS;
		ROLLBACK;
		SET p_ErrID = 1000;
	END;
-- -------------------------------------------------------------------------

	SET p_ErrID = 0;
/*
--  Checking For User Privilege [Only SuperAdmin Or BusinessAdmin Of Corresponding Loaction Is Allowed]
	IF NOT EXISTS(	SELECT 1 	-- Business Admin
					FROM BusinessLocation BL
					JOIN Business B ON BL.BusinessID = B.BusinessID
						AND BL.BusinessLocationID = p_BusinessLocationID
					JOIN BusinessAdmin BA ON B.BusinessID = BA.BusinessID
					WHERE BA.UserID = p_LoggedinUserID
					UNION ALL
					SELECT 1 -- Super Admin
					FROM `User` 
					WHERE UserID = p_LoggedinUserID 
						AND UserType = 1) 
	THEN
		SET p_ErrID = 1052; -- Only Admin User Is Allowed To Create/Modify User
		LEAVE PROC;	
	END IF;
*/

--  Checking For Existance Of This User Under Another Business 
	IF EXISTS(SELECT 1 
				FROM `User` U
                JOIN Contact C ON U.ContactID = C.ContactID
					AND C.Email = p_Email
					AND C.IsDeleted = 0
				JOIN BusinessLocationUser BLU ON U.UserID = BLU.UserID
                    AND BLU.BusinessLocationID <> p_BusinessLocationID)
    THEN
		SET p_ErrID = 1100; -- User Already Exists Under Another BusinessLocation
		LEAVE PROC;	
	END IF;
    
--  Checking for Email Duplication
	IF EXISTS(SELECT 1 
				FROM `User` U
                JOIN Contact C ON U.ContactID = C.ContactID
					AND C.Email = p_Email
					AND C.IsDeleted = 0
                    AND U.UserID <> p_UserID)
    THEN
		SET p_ErrID = 1016; -- Email Already Exists
		LEAVE PROC;	
	END IF;
    
--  Checking for Phone Duplication
	IF EXISTS(SELECT 1 
				FROM `User` U
                JOIN Contact C ON U.ContactID = C.ContactID
                    AND -- CONCAT(IFNULL(C.CountryCode,''),C.Phone) = CONCAT(IFNULL(p_CountryCode,''),p_Phone)
						IFNULL(C.CountryCode,'') = IFNULL(p_CountryCode,'') AND C.Phone = p_Phone	-- Performance fix
					AND C.IsDeleted = 0
                    AND U.UserID <> p_UserID)
    THEN
		SET p_ErrID = 1017; -- Phone Already Exists
		LEAVE PROC;	
	END IF;

--  Checking Location-Role Associativity For Security
	IF NOT EXISTS(SELECT 1 FROM BusinessLocationRole WHERE BusinessLocationID = p_BusinessLocationID AND RoleID = p_RoleID)THEN
		SET p_ErrID = 1018; -- Role Doesn't Belong To This Location
		LEAVE PROC;	
	END IF;
    
-- 	Determining UserType [ 3:Vendor-User, 4: Restaurant-User ]
    SELECT IF(B.BusinessType=1,3,4) INTO l_UserType
    FROM BusinessLocation BL
    JOIN Business B ON BL.BusinessID = B.BusinessID
		AND BL.BusinessLocationID = p_BusinessLocationID;

-- 	Getting User's DefaultRoleID
	SELECT DefaultRoleID INTO l_DefaultRoleID FROM `Role` WHERE RoleID = p_RoleID;

	START TRANSACTION;    
	
    IF p_UserID = 0 THEN
	--  Adding User-Contact
		INSERT Contact
				(	Email, 
					CountryCode,
					Phone, 
                    CreatedBy
				)
		VALUES	(	p_Email, 
					p_CountryCode,
					p_Phone, 
                    p_LoggedinUserID
				);
		SET l_ContactID = LAST_INSERT_ID();
        
	--  Adding User Profile
		SELECT UUID() INTO l_UserGUID;
		INSERT `User`
				(	UserGUID, 
					UserType, 
                    FirstName, 
                    LastName, 
                    ContactID, 
                    CreatedBy
				)
		VALUES	(	l_UserGUID, 
					l_UserType,
					p_FirstName, 
					p_LastName, 
					l_ContactID, 
					p_LoggedinUserID
				);
		SET p_UserID = LAST_INSERT_ID();

	--  Creating Login For User
		INSERT UserLogin
				(	UserID, 
					UserName,
					LoginPwd)
		VALUES	(	p_UserID, 
					p_Email,
					p_DefaultPwd
				);
                
    -- 	Adding User Under BusinessLocation & Assigning Role
		INSERT BusinessLocationUser
				(	BusinessLocationID, UserID, RoleID)
		VALUES	(	p_BusinessLocationID, p_UserID, p_RoleID);
        
	--  Adding Default Notification Settings [Not required for cusotm Roles]
		IF IFNULL(l_DefaultRoleID,0) <> 0 THEN
			INSERT UserNotificationSetting
				(	UserID, NotificationTypeID, SendText, SendEmail, SendPush)
			SELECT 	p_UserID, NotificationTypeID, SendText, SendEmail, SendPush
			FROM DefaultRoleNotificationType 
			WHERE RoleID = IFNULL(l_DefaultRoleID,0) -- User's DefautRoleID
				AND (SendText = 1 OR SendEmail = 1 OR SendPush = 1);
		END IF;
        
    ELSE
	-- 	Updating User Profile
		UPDATE `User`
        SET FirstName 	= p_FirstName,
			LastName	= p_LastName,
            EditedBy	= p_LoggedinUserID,
            EditedOn	= UTC_TIMESTAMP()
		WHERE UserID = p_UserID;
	
    -- 	Updating Contact Info
        UPDATE Contact C
        JOIN `User` U ON C.ContactID = U.ContactID
			AND U.UserID = p_UserID
        SET C.Email 		= p_Email,
			C.CountryCode 	= p_CountryCode,
			C.Phone			= p_Phone,
            C.EditedBy		= p_LoggedinUserID,
            C.EditedOn		= UTC_TIMESTAMP();

	-- 	Updating Login Email
		UPDATE UserLogin
		SET UserName = p_Email,
			EditedOn =  UTC_TIMESTAMP()
		WHERE UserID = p_UserID;
    
	-- 	Updating User-Role
		UPDATE BusinessLocationUser
        SET RoleID = p_RoleID
		WHERE BusinessLocationID = p_BusinessLocationID
			AND UserID = p_UserID;
    END IF;

	COMMIT;  
	
-- 	Return User Info
	SELECT p_UserID AS UserID, l_UserGUID AS UserGUID;
    
END$$
DELIMITER ;
