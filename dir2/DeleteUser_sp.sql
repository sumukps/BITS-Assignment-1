DROP PROCEDURE IF EXISTS `DeleteUser_sp`;
DELIMITER $$
CREATE PROCEDURE `DeleteUser_sp`(
	IN  p_UserGUID			VARCHAR(50),
	IN  p_LoggedinUserID	BIGINT,
	OUT p_ErrID   			BIGINT
)
PROC: 
BEGIN
/*
*********************************************************************************************
Project/Module	    :	Madchef
Purpose				:	To Delete A User And Login information
-----------------------------------------------------------------------------------------------  
Return Values       :      0 - Success   
						1000 - Unexpected Error 
                        1069 - User Not Exists
                        1068 - Cannot Delete, SalesPerson Assignment Exists
-----------------------------------------------------------------------------------------------                 
Call Syntax         : 
						SET @p_UserGUID	 		= '5525ba2e-cee9-11ec-8aab-02e7b876c79a';
                        SET @p_LoggedinUserID	= 1;
						CALL DeleteUser_sp(@p_UserGUID,@p_LoggedinUserID,@p_ErrID); 
					    SELECT @p_ErrID;  

************************************************************************************************
Change History
************************************************************************************************
Date			Author				Revision    Description
------------------------------------------------------------------------------------------------
13-FEB-2022		Zco Engr						Created    
***********************************************************************************************
*/
	DECLARE l_UserID BIGINT UNSIGNED DEFAULT 0; 
-- -------------------------------------------------------------------------
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
		SHOW ERRORS;
		ROLLBACK;
		SET p_ErrID = 1000;
	END;
-- -------------------------------------------------------------------------

	SET p_ErrID = 0;
	
    SELECT UserID INTO l_UserID
    FROM `User` 
    WHERE UserGUID = p_UserGUID
		AND UserType NOT IN(1,2);

--  Checking User Existance
	IF IFNULL(l_UserID,0) = 0 THEN
		SET p_ErrID = 1069; -- User Not Exists
		LEAVE PROC;	
	END IF;
    
--  Checking For SalesPerson Assignment
	IF EXISTS(SELECT 1 
				FROM VendorRestaurant VR 
				WHERE VR.SalesPersonUserID = l_UserID
					AND VR.IsDeleted = 0 LIMIT 1)
    THEN
		SET p_ErrID = 1068; -- Cannot Delete, SalesPerson Assignment Exists
		LEAVE PROC;	
	END IF;
    
	START TRANSACTION;    
	
    UPDATE `User`
    SET IsDeleted = 1,
		EditedBy = p_LoggedinUserID,
		EditedOn = UTC_TIMESTAMP()
    WHERE UserID = l_UserID;
 
	UPDATE Contact
    SET IsDeleted = 1,
		EditedBy = p_LoggedinUserID,
		EditedOn = UTC_TIMESTAMP()
    WHERE ContactID IN (SELECT ContactID FROM `User` WHERE UserID = l_UserID);
    
	DELETE FROM UserNotificationSetting WHERE UserID = l_UserID;
    DELETE FROM UserLogin WHERE UserID = l_UserID;
    DELETE FROM UserPIN WHERE UserID = l_UserID;
    
	COMMIT;  
    
END$$
DELIMITER ;
