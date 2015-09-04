--[[
%% properties
READER_DEVICE_ID_HERE userCodes
%% globals
--]]

--[[

Simple alarm script for Zipato Mini Keypad RFID - Fibaro HC2

Version	1.1

*** NEXT RELEASE ***
Who knows... Your idea?

*** 04-09-2015 ***
[ADD] Rfid tags is now in 1 table, so it's possible to add more tags without having to change the check code

*** 03-09-2015 ***
First Version

Credits:
clausdk
http://shop.tecmatic.ch/de/blog/22-zipato-rfid-reader-and-fibaro-home-center-2


--]]

--------------------------------------------------------
-- Configuration BEGIN
--------------------------------------------------------

-- Tag reader ID
local tagReader = READER_DEVICE_ID_HERE 

-- Sirene ID
local sirene = 413 

-- Alarm modes:

-- Mode 0 - Alarm script disabled
-- Mode 1 - Default Alarm script mode. Checks Rfid tags and pincode. Arm and disarm alarm system.
-- Mode 2 - Debug mode - Alarm disabled, but prints tags/pincode into the debug console ( Use this to add new tags/pincodes in the table )

local alarmMode = 1

-- Push messages

-- Mode 0 - Push messages disabled
-- Mode 1 - Push messages will only be sent to the admin account
-- Mode 2 - Push messages will be sent to all in the push

local pushEnabled = 1

-- Admin device ID
local pushAdminDeviceID = 0

-- Admin Email (NOT WORKING YET)
local pushAdminEmail = "my@email.com"

-- Code table ( You can add more or delete the onces you do not use )

-- type - Rfid tag or Pincode ( 1 = Rfid, 2 = Pincode, 3 = Used for arming - Can only be used once)
-- code - Push messages enabled
-- owner - This is the name that will be sent in push message ( Alarm Enabled by owner )
-- allpush - If allpush is true, this user will recieve ALL push messages when a tag is scanned or pincode is being entered.
-- deviceid - If you put the device ID here, there will be sent a push message to this device when the tag or pincode is entered
-- email - (NOT WORKING YET) If you put an email address in here, there will be sent a push message to this email when the tag or pincode is entered

local codeTable = {
					-- Rfid tags 
					{ type = '1', code = { 143, 47, 183, 84, 42, 0, 1, 4, 0, 0 }, owner = 'Mom', allpush = true, deviceid = '511', email = '' },
					{ type = '1', code = { 123, 33, 221, 84, 42, 0, 1, 4, 0, 0 }, owner = 'Dad', allpush = false, deviceid = '213', email = '' },
					{ type = '1', code = { 131, 44, 221, 84, 42, 0, 1, 4, 0, 0 }, owner = 'Grandma', allpush = false, deviceid = '241', email = '' },
					{ type = '1', code = { 143, 47, 183, 84, 42, 0, 1, 4, 0, 0 }, owner = 'Grandpa', allpush = false, deviceid = '215', email = '' },
					
					-- Arming function ( Dont remove!!! )
					{ type = '3', code = { 49, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, owner = '', allpush = false, deviceid = '', email = '' },
} 

-- Check before Arming the alarm
local checkBeforeArm = {143, 332} -- Device IDs ( Windows, doors?)

-- Force Arm table
local forceArm = {143, 332 } -- Force arms the devices with those IDs ( Motion sensors, Windows, Doors? )

--------------------------------------------------------
-- Configuration END
--------------------------------------------------------


--------------------------------------------------------
-- Functions
--------------------------------------------------------

-- Tag reader start value
local readerCode = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local function sendPush( deviceId, message )

	fibaro:call(deviceId, "sendPush", message);

end

local function sendPushGroups( code, message )

	if (pushEnabled == 0)  then
		return false
	elseif (pushEnabled == 1) then
		sendPush( pushAdminDeviceID, message )
		return true
	elseif (pushEnabled == 2) then
		sendPush( pushAdminDeviceID, message )
		for k, v in pairs(codeTable) do
			if ( v["allpush"] == true and compareCodeTable(code) ) then
				sendPush( v["deviceid"], message )
			elseif ( compareCodeTable(code) ) then
				sendPush( v["deviceid"], message )
			end
		end
		return true
	end

end

local function armingDevice( deviceId, action )

	if (action == 0) then
		fibaro:call( deviceId, "setArmed", "0" );
	elseif (action == 1) then
		fibaro:call( deviceId, "forceArm");
	end
	
end

local function armingCheck( deviceId )

	if (tonumber(fibaro:getValue(deviceId, "value")) > 0) then
		return true
	else
		return false
	end
	
end

local function armingCheckTable( )

	for k, v in pairs(checkBeforeArm) do
		if armingCheck(v) then
		return true
		end
	end
	return false -- Maybe send back IDs and print the name of the device...
	
end

local function compareCodeArrays( array1, array2 )

  if (#array1 ~= 10 or #array2 ~= 10) then
    fibaro:debug("Array code not vaild!")
    return false
  end
  for i = 1, #array1 do
    if (array1[i] ~= array2[i]) then
      return false
    end
  end
  
  return true
  
end

function compareCodeTable( inputCode )

	for k, v in pairs(codeTable) do
		local code = v["code"]
		if compareCodeArrays(code, inputCode) then
			return true
		end
	end
	return false 
	
end

function getValueCodeTable( code, id )

	for k, v in pairs(codeTable) do
		if compareCodeArrays( v["code"], code ) then
			return v[id]
		end
	end
	return nil
end

local startSource = fibaro:getSourceTrigger()

if (startSource["deviceID"] == tagReader) then

	if (alarmMode == 0) then
		
		fibaro:debug("Alarm script is deactivated. Please check the configuration if you want to enable it again.")
		
	elseif (alarmMode == 1) then
	  
	  local userCodes = fibaro:get(tagReader, "userCodes") -- Get user table from reader

	  jsontbl = json.decode(userCodes)

	  for i = 1, #jsontbl do
	  if (jsontbl[i].id == 0) then
		  
		for b = 1, string.len(jsontbl[i].code) do 
			readerCode[b] = string.byte(jsontbl[i].code,b)
		end
		
		-- Compare codes
		if (checkCodeTable(readerCode)) then -- Checks if the code exists in our table
		
			-- lets get the type from the codeTable
			local codeType = getValueCodeTable( readerCode, "type" )
			
		
			if (codeType == 3) then -- Arming code here....
			
			if not armingCheckTable( ) then -- Check the arm table before arming the alarm system 
			
				sendPushGroups( "", "Sorry, but something prevents the alarm from being armed. Please check your windows and doors is closed." )
			else
				-- for now we will forcearm the devices... maybe later make a check code to check if arming is possible?
				for k, v in pairs(forceArm) do
					armingDevice( deviceId, 1 )
				end
			end
				
			elseif (codeType == 1) then
			
				for k, v in pairs(forceArm) do
					armingDevice( deviceId, 0 )
					
					-- Maybe you would like turn turn off a sirene 
					fibaro:call(sirene, "turnOff")
					
				end
			
			elseif (codeType == 2) then
			
			-- You can add your own functions here...
			
			-- yourCode = { 49, 50, 0, 0, 0, 0, 0, 0, 0, 0 }
			-- if ( compareCodeTable(yourCode) ) then
			-- fibaro:debug("Hello world!")
			-- end
			
			end	
			
			end
		  
		  
		end 
		end
	elseif (alarmMode == 2) then
	  
			local userCodes = fibaro:get(tagReader, "userCodes") -- Get user table from reader

			jsontbl = json.decode(userCodes)

			for i = 1, #jsontbl do
			if (jsontbl[i].id == 0) then
			  
			for b = 1, string.len(jsontbl[i].code) do 
				readerCode[b] = string.byte(jsontbl[i].code,b)
			end
		
			-- Print code on Fibaro scene debug page
			fibaro:debug("Code from Reader: {" .. readerCode[1] .. ", " .. readerCode[2] .. ", " .. readerCode[3] .. ", " .. readerCode[4] .. ", " .. readerCode[5] .. ", " .. readerCode[6] .. ", " .. readerCode[7] .. ", " .. readerCode[8] .. ", " .. readerCode[9] .. ", " .. readerCode[10] .. "}")
			fibaro:debug("You can copy and paste this into the code table..")
			
			end
			end

	else

		fibaro:debug("Sorry the Tag/Pincode could not be found in the code table.")
		
	end

end