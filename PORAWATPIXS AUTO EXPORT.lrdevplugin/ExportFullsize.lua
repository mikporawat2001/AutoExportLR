-- Access the Lightroom SDK namespaces.
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

-- Process pictures and save them as JPEG
local function processPhotos(photos, outputFolder)
	LrFunctionContext.callWithContext("export", function(exportContext)

		local progressScope = LrDialogs.showModalProgressDialog({
			title = "Auto applying presets",
			caption = "",
			cannotCancel = false,
			functionContext = exportContext
		})

		local exportSession = LrExportSession({
			photosToExport = photos,
			exportSettings = {
				LR_collisionHandling = "rename",
				LR_export_bitDepth = "8",
				LR_export_colorSpace = "sRGB",
				LR_export_destinationPathPrefix = outputFolder,
				LR_export_destinationType = "specificFolder",
				LR_export_useSubfolder = false,
				LR_format = "JPEG",
				LR_jpeg_quality = 1,
				LR_minimizeEmbeddedMetadata = true,
				LR_outputSharpeningOn = false,
				LR_reimportExportedPhoto = false,
				LR_renamingTokensOn = true,
				-- LR_size_doConstrain = true,
				LR_size_doNotEnlarge = true,
				-- LR_size_maxHeight = 2000,
				-- LR_size_maxWidth = 2000,
				LR_size_resolution = 300,
				LR_size_units = "pixels",
				LR_tokens = "{{image_name}}",
				LR_useWatermark = false,
			}
		})

		local numPhotos = exportSession:countRenditions()

		local renditionParams = {
			progressScope = progressScope,
			renderProgressPortion = 1,
			stopIfCanceled = true,
		}

		for i, rendition in exportSession:renditions(renditionParams) do

			-- Stop processing if the cancel button has been pressed
			if progressScope:isCanceled() then
				break
			end

			-- Common caption for progress bar
			local progressCaption = rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos .. ")"

			progressScope:setPortionComplete(i - 1, numPhotos)
			progressScope:setCaption("Processing " .. progressCaption)

			rendition:waitForRender()
		end
	end)
end

-- Import pictures from folder where the rating is not 2 stars 
local function importFolder(LrCatalog, folder, outputFolder)
	local presetFolders = LrApplication.developPresetFolders()
	local presetFolder = presetFolders[1]
	local presets = presetFolder:getDevelopPresets()
	LrTasks.startAsyncTask(function()
		local photos = folder:getPhotos()
		local export = {}

		for _, photo in pairs(photos) do
			if (photo:getRawMetadata("rating") ~= 3 ) then
				LrCatalog:withWriteAccessDo("Apply Preset", function(context)
					for _, preset in pairs(presets) do
						photo:applyDevelopPreset(preset)
					end
					photo:setRawMetadata("rating", 3)
					table.insert(export, photo)
				end)
			end
		end

		if #export > 0 then
			processPhotos(export, outputFolder)
		end
	end)
end

-- GUI specification
local function customPicker()
	LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)

		local props = LrBinding.makePropertyTable(context)
		local f = LrView.osFactory()

		local outputFolderField = f:edit_field {
			immediate = true,
			value = "D:\\Pictures"
		}

		local staticTextValue = f:static_text {
			title = "ยังไม่มีการทำงาน",
		}

		local function myCalledFunction()
			staticTextValue.title = props.myObservedString
		end

		LrTasks.startAsyncTask(function()

			local LrCatalog = LrApplication.activeCatalog()
			local catalogFolders = LrCatalog:getFolders()
			local folderCombo = {}
			local folderIndex = {}
			for i, folder in pairs(catalogFolders) do
				folderCombo[i] = folder:getName()
				folderIndex[folder:getName()] = i
			end

			local folderField = f:combo_box {
				items = folderCombo
			}

			local watcherRunning = false

			-- Watcher, executes function and then sleeps 60 seconds using PowerShell
			local function watch()
				LrTasks.startAsyncTask(function()
					while watcherRunning do
						LrDialogs.showBezel("Processing images.")
						importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value)
						if LrTasks.canYield() then
							LrTasks.yield()
						end
						LrTasks.execute("powershell Start-Sleep -Seconds 3")
					end
				end)
			end

			props:addObserver("myObservedString", myCalledFunction)

			local c = f:column {
				spacing = f:dialog_spacing(),
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "สถานะการทำงาน: "
					},
					staticTextValue,
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "เลือกโฟลเดอร์: "
					},
					folderField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "ตำแหน่งที่อัพโหลด: "
					},
					outputFolderField
				},
				f:row {
					f:push_button {
						title = "อัพโหลด",

						action = function()
							if folderField.value ~= "" then
								props.myObservedString = "อัพโหลดสำเร็จ"
								importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value)
							else
								LrDialogs.message("Please select an input folder")
							end
						end
					},
					f:push_button {
						title = "อัพโหลดอัตโนมัติ",

						action = function()
							watcherRunning = true
							if folderField.value ~= "" then
								props.myObservedString = "กำลังอัพโหลด"
								watch()
							else
								LrDialogs.message("Please select an input folder")
							end
						end
					},
					f:push_button {
						title = "หยุดการทำงาน",

						action = function()
							watcherRunning = false
							props.myObservedString = "ยังไม่มีการทำงาน"
						end
					}
				},
			}

			LrDialogs.presentModalDialog {
				title = "PORAWATPIXS AUTO EXPORT",
				contents = c,
				-- Preferrably cancel should stop the script 
				-- OK can be changed to run in background
				-- actionBinding = {
				-- 	enabled = {
				-- 		bind_to_object = props,
				-- 		key = 'actionDisabled'
				-- 	},
				-- }			   
			}

		end)

	end)
end

customPicker()
