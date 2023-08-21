return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'nl.olafhaalstra.lightroom.PORAWATPIXS AUTO EXPORT',

	LrPluginName = LOC "$$$/PORAWATPIXS AUTO EXPORT/PluginName=PORAWATPIXS AUTO EXPORT",

	LrExportMenuItems = {{
		title = "PORAWATPIXS AUTO EXPORT Resize 2048 px",
		file = "ExportResize.lua",		
	},{
		title = "PORAWATPIXS AUTO EXPORT Fullsize",
		file = "ExportFullsize.lua",		
	},},
	VERSION = { major=1, minor=0, revision=0, build="20220724", },

}


	
