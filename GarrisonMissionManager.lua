local dump = DevTools_Dump
local tinsert = table.insert
local wipe = wipe
local pairs = pairs
local GARRISON_CURRENCY = GARRISON_CURRENCY
local GarrisonMissionFrame = GarrisonMissionFrame
local GarrisonLandingPage = GarrisonLandingPage
local GarrisonRecruitSelectFrame = GarrisonRecruitSelectFrame
local MissionPage = GarrisonMissionFrame.MissionTab.MissionPage
local AddFollowerToMission = C_Garrison.AddFollowerToMission
local GetPartyMissionInfo = C_Garrison.GetPartyMissionInfo
local RemoveFollowerFromMission = C_Garrison.RemoveFollowerFromMission

local buttons = {}

function GMM_dumpl(pattern, ...)
   local names = { strsplit(",", pattern) }
   for idx = 1, select('#', ...) do
      local name = names[idx]
      if name then name = name:gsub("^%s+", ""):gsub("%s+$", "") end
      print(GREEN_FONT_COLOR_CODE, idx, name, FONT_COLOR_CODE_CLOSE)
      dump(select(idx, ...))
   end
end

local _, _, garrison_currency_texture = GetCurrencyInfo(GARRISON_CURRENCY)
garrison_currency_texture = "|T" .. garrison_currency_texture .. ":0|t"
local time_texture = "|TInterface\\Icons\\spell_holy_borrowedtime:0|t"

local min, max = {}, {}
local top = {{}, {}, {}, {}}
local function FindBestFollowersForMission(mission, followers)
   local followers_count = #followers

   for idx = 1, 3 do
      wipe(top[idx])
   end

   local slots = mission.numFollowers
   if slots > followers_count then return end

   GarrisonMissionFrame:UnregisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")
   GarrisonLandingPage:UnregisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")
   GarrisonRecruitSelectFrame:UnregisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")

   local mission_id = mission.missionID
   if C_Garrison.GetNumFollowersOnMission(mission_id) > 0 then
      for idx = 1, #followers do
         C_Garrison.RemoveFollowerFromMission(mission_id, followers[idx].followerID)
      end
   end

   for idx = 1, slots do
      max[idx] = followers_count - slots + idx
      min[idx] = nil
   end
   for idx = slots+1, 3 do
      max[idx] = followers_count + 1
      min[idx] = followers_count + 1
   end

   local currency_rewards
   for _, reward in pairs(mission.rewards) do
      if reward.currencyID == GARRISON_CURRENCY then currency_rewards = true break end
   end

   for i1 = 1, max[1] do
      local follower1 = followers[i1]
      local follower1_id = follower1.followerID
      for i2 = min[2] or (i1 + 1), max[2] do
         local follower2 = followers[i2]
         local follower2_id = follower2 and follower2.followerID
         for i3 = min[3] or (i2 + 1), max[3] do
            -- Assign followers to mission
            local follower3 = followers[i3]
            local follower3_id = follower3 and follower3.followerID
            
            if not AddFollowerToMission(mission_id, follower1.followerID) then --[[ error handling! ]] end
            if follower2 and not AddFollowerToMission(mission_id, follower2_id) then --[[ error handling! ]] end
            if follower3 and not AddFollowerToMission(mission_id, follower3_id) then --[[ error handling! ]] end

            -- Calculate result
            local totalTimeString, totalTimeSeconds, isMissionTimeImproved, successChance, partyBuffs, isEnvMechanicCountered, xpBonus, materialMultiplier = GetPartyMissionInfo(mission_id)
            for idx = 1, 3 do
               local current = top[idx]
               local found
               repeat -- Checking if new candidate for top is better than any top 3 already sored
                  -- TODO: risk lower chance mission if material multiplier gives better average result
                  if not current[1] then found = true break end

                  if current.successChance < successChance then found = true break end
                  if current.successChance > successChance then break end

                  if currency_rewards then
                     if current.materialMultiplier < materialMultiplier then found = true break end
                     if current.materialMultiplier > materialMultiplier then break end
                  end

                  if current.xpBonus < xpBonus then found = true break end
                  if current.xpBonus > xpBonus then break end

                  if current.totalTimeSeconds > totalTimeSeconds then found = true break end
                  if current.totalTimeSeconds < totalTimeSeconds then break end
               until true
               if found then
                  local new = top[4]
                  new[1] = follower1
                  new[2] = follower2
                  new[3] = follower3
                  new.successChance = successChance
                  new.materialMultiplier = materialMultiplier
                  new.currency_rewards = currency_rewards
                  new.xpBonus = xpBonus
                  new.totalTimeSeconds = totalTimeSeconds
                  new.isMissionTimeImproved = isMissionTimeImproved
                  tinsert(top, idx, new)
                  top[5] = nil
                  break
               end
            end

            -- Unasssign
            RemoveFollowerFromMission(mission_id, follower1_id)
            if follower2 then RemoveFollowerFromMission(mission_id, follower2_id) end
            if follower3 then RemoveFollowerFromMission(mission_id, follower3_id) end
         end
      end
   end

   GarrisonMissionFrame:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")
   GarrisonLandingPage:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")
   GarrisonRecruitSelectFrame:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")

   -- dump(top)
   -- local location, xp, environment, environmentDesc, environmentTexture, locPrefix, isExhausting, enemies = C_Garrison.GetMissionInfo(missionID);
   -- /run GMM_dumpl("location, xp, environment, environmentDesc, environmentTexture, locPrefix, isExhausting, enemies", C_Garrison.GetMissionInfo(GarrisonMissionFrame.MissionTab.MissionPage.missionInfo.missionID))
   -- /run GMM_dumpl("totalTimeString, totalTimeSeconds, isMissionTimeImproved, successChance, partyBuffs, isEnvMechanicCountered, xpBonus, materialMultiplier", C_Garrison.GetPartyMissionInfo(GarrisonMissionFrame.MissionTab.MissionPage.missionInfo.missionID))
   -- /run GMM_BestForCurrentSelectedMission()
end

-- TODO: don't update list if it is not dirty
local filtered_followers = {}
local filtered_followers_count
local function GetFilteredFollowers()
   local followers = C_Garrison.GetFollowers()
   wipe(filtered_followers)
   filtered_followers_count = 0
   for idx = 1, #followers do
      local follower = followers[idx]
      repeat
         if not follower.isCollected then break end
         local status = follower.status
         if status then break end

         filtered_followers_count = filtered_followers_count + 1
         filtered_followers[filtered_followers_count] = follower
      until true
   end

   -- dump(filtered_followers)
   return filtered_followers, filtered_followers_count
end

local available_missions = {}
local function GMM_BestForCurrentSelectedMission()
   local missionInfo = MissionPage.missionInfo
   local mission_id = missionInfo.missionID

   -- print("Mission ID:", mission_id)

   local filtered_followers, filtered_followers_count = GetFilteredFollowers()

   C_Garrison.GetAvailableMissions(available_missions)
   local mission
   for idx = 1, #available_missions do
      if available_missions[idx].missionID == mission_id then
         mission = available_missions[idx]
         break
      end
   end

   -- dump(mission)

   FindBestFollowersForMission(mission, filtered_followers)

   if not buttons['MissionPage1'] then GMM_ButtonsInit() end
   for idx = 1, 3 do
      local button = buttons['MissionPage' .. idx]
      local top_entry = top[idx]
      button[1] = top_entry[1] and top_entry[1].followerID or nil
      button[2] = top_entry[2] and top_entry[2].followerID or nil
      button[3] = top_entry[3] and top_entry[3].followerID or nil
      if top_entry.successChance then
         button:SetFormattedText(
            "%d%%\n%s%s%s",
            top_entry.successChance,
            top_entry.xpBonus > 0 and top_entry.xpBonus .. " |TInterface\\Icons\\XPBonus_Icon:0|t" or "",
            (top_entry.currency_rewards and top_entry.materialMultiplier > 1) and garrison_currency_texture or "",
            top_entry.isMissionTimeImproved and time_texture or ""
         )
      else
         button:SetText("")
      end
   end

end

local function PartyButtonOnClick(self)
   if self[1] then
      local MissionPageFollowers = GarrisonMissionFrame.MissionTab.MissionPage.Followers
      for idx = 1, #MissionPageFollowers do
         GarrisonMissionPage_ClearFollower(MissionPageFollowers[idx])
      end
      
      for idx = 1, #MissionPageFollowers do
         local followerFrame = MissionPageFollowers[idx]
         local follower = self[idx]
         if follower then
            local followerInfo = C_Garrison.GetFollowerInfo(follower)
            GarrisonMissionPage_SetFollower(followerFrame, followerInfo)
         end
      end
   end

   GarrisonMissionPage_UpdateMissionForParty()
end

-- Add more data to mission list over Blizzard's own
-- GarrisonMissionList_Update
local function GarrisonMissionList_Update_More()
   local self = GarrisonMissionFrame.MissionTab.MissionList
   if (self.showInProgress) then return end
   
   local missions = self.availableMissions
   local numMissions = #missions
   if (numMissions == 0) then return end

   local missions = self.availableMissions
   local scrollFrame = self.listScroll
   local offset = HybridScrollFrame_GetOffset(scrollFrame)
   local buttons = scrollFrame.buttons
   local numButtons = #buttons

   local filtered_followers, filtered_followers_count = GetFilteredFollowers()
   
   for i = 1, numButtons do
      local button = buttons[i]
      local alpha = 1
      local index = offset + i
      if index <= numMissions then
         local mission = missions[index]
         -- dump(mission)
         if mission.numFollowers > filtered_followers_count then
            alpha = 0.3
         else
            -- buttons will be added here
         end
      end
      button:SetAlpha(alpha)
   end
end
--       hooksecurefunc("GarrisonMissionList_Update", GarrisonMissionList_Update_More)

local function GMM_ButtonsInit()
   local prev
   for idx = 1, 3 do
      if not buttons['MissionPage' .. idx] then
         local set_followers_button = CreateFrame("Button", nil,  GarrisonMissionFrame.MissionTab.MissionPage, "UIPanelButtonTemplate")
         set_followers_button:SetText(idx)
         set_followers_button:SetWidth(100)
         set_followers_button:SetHeight(50)
         if not prev then
            set_followers_button:SetPoint("TOPLEFT", GarrisonMissionFrame.MissionTab.MissionPage, "TOPRIGHT", 0, 0)
         else
            set_followers_button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0)
         end
         set_followers_button:SetScript("OnClick", PartyButtonOnClick)
         set_followers_button:Show()
         prev = set_followers_button
         buttons['MissionPage' .. idx] = set_followers_button
      end
   end
end
GMM_ButtonsInit()
hooksecurefunc("GarrisonMissionPage_ShowMission", GMM_BestForCurrentSelectedMission)
-- local count = 0
-- hooksecurefunc("GarrisonFollowerList_UpdateFollowers", function(self) count = count + 1 print("GarrisonFollowerList_UpdateFollowers", count, self:GetName(), self:GetParent():GetName()) end)

-- Globals deliberately exposed for people outside
function GMM_Click(button_name)
   local button = buttons[button_name]
   if button then button:Click() end
end

