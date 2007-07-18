; Texter
; Author:         Adam Pash <adam@lifehacker.com>
; Gratefully adapted several ideas from AutoClip by Skrommel:
;		http://www.donationcoder.com/Software/Skrommel/index.html#AutoClip
; Huge thanks to Dustin Luck for his contributions
; Script Function:
;	Designed to implement simple, on-the-fly creation and managment 
;	of auto-replacing hotstrings for repetitive text
;	http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php
SetWorkingDir %A_ScriptDir%
#SingleInstance,Force 
#NoEnv
StringCaseSense On
AutoTrim,off
SetKeyDelay,-1
SetWinDelay,0 
Gosub,UpdateCheck
Gosub,ASSIGNVARS
Gosub,READINI
EnableTriggers(true)
Gosub,RESOURCES
Gosub,TRAYMENU
Gosub,BuildActive
if AutoCorrect = 1
	Gosub,AUTOCORRECT
;Gosub,AUTOCLOSE

FileRead, EnterKeys, %EnterCSV%
FileRead, TabKeys, %TabCSV%
FileRead, SpaceKeys, %SpaceCSV%
;Gosub,GetFileList
Goto Start

START:
EnableTriggers(true)
hotkey = 
executed = false
Input,input,V L99,{SC77}
input:=hexify(input)
IfInString,ActiveList,%input%|
{ ;input matches a hotstring -- see if hotkey matches a trigger for hotstring
	if hotkey in %ignore%
	{
		StringTrimLeft,Bank,hotkey,1
		StringTrimRight,Bank,Bank,1
		Bank = %Bank%Keys
		Bank := %Bank%
		if input in %Bank%
		{
			GoSub, EXECUTE
			executed = true
		}
	}
}
if executed = false
{
	SendInput,%hotkey%
}
Goto,START
return

EXECUTE:
WinGetActiveTitle,thisWindow ; this variable ensures that the active Window is receiving the text, activated before send
;; below added b/c SendMode Play appears not to be supported in Vista 
EnableTriggers(false)
if (A_OSVersion = "WIN_VISTA") or (Synergy = 1) ;;; need to implement this in the preferences - should work, though
	SendMode Input
else
	SendMode Play   ; Set an option in Preferences to enable for use with Synergy - Use SendMode Input to work with Synergy
if (ExSound = 1)
	SoundPlay, %ReplaceWAV%
ReturnTo := 0
hexInput:=Dehexify(input)
StringLen,BSlength,hexInput
Send, {BS %BSlength%}
FileRead, ReplacementText, %A_ScriptDir%\Active\replacements\%input%.txt
StringLen,ClipLength,ReplacementText

IfInString,ReplacementText,::scr::
{
	;To fix double spacing issue, replace `r`n (return + new line) as AHK sends a new line for each character
	StringReplace,ReplacementText,ReplacementText,`r`n,`n, All
	StringReplace,ReplacementText,ReplacementText,::scr::,,
	IfInString,ReplacementText,`%p
	{
		textPrompt(ReplacementText)
	}
	IfInString,ReplacementText,`%s
	{
		StringReplace, ReplacementText, ReplacementText,`%s(, �, All
		Loop,Parse,ReplacementText,�
		{
			if (A_Index != 1)
			{
				StringGetPos,len,A_LoopField,)
				StringTrimRight,sleepTime,A_LoopField,%len%
				StringMid,thisScript,A_LoopField,(len + 2),
				Sleep,%sleepTime%
				;WinActivate,%thisWindow%  The assumption must be made that in script mode
				; the user can intend to enter text in other windows
				SendInput,%thisScript%
			}
			else
			{
				;WinActivate,%thisWindow%  The assumption must be made that in script mode
				; the user can intend to enter text in other windows
				SendInput,%A_LoopField%
			}
		}
	}
	else
		SendInput,%ReplacementText%
	return
}
else
{
	;To fix double spacing issue, replace `r`n (return + new line) as AHK sends a new line for each character
	;(but only in compatibility mode)
	if MODE = 0
	{
		StringReplace,ReplacementText,ReplacementText,`r`n,`n, All
	}
	IfInString,ReplacementText,`%c
	{
		StringReplace, ReplacementText, ReplacementText, `%c, %Clipboard%, All
	}
	IfInString,ReplacementText,`%t
	{
		FormatTime, CurrTime, , Time
		StringReplace, ReplacementText, ReplacementText, `%t, %CurrTime%, All
	}
	IfInString,ReplacementText,`%ds
	{
		FormatTime, SDate, , ShortDate
		StringReplace, ReplacementText, ReplacementText, `%ds, %SDate%, All
	}
	IfInString,ReplacementText,`%dl
	{
		FormatTime, LDate, , LongDate
		StringReplace, ReplacementText, ReplacementText, `%dl, %LDate%, All
	}
	IfInString,ReplacementText,`%p
	{
		textPrompt(ReplacementText)
	}
	IfInString,ReplacementText,`%|
	{
		;in clipboard mode, CursorPoint & ClipLength need to be calculated after replacing `r`n
		if MODE = 0
		{
			MeasurementText := ReplacementText
		}
		else
		{
			StringReplace,MeasurementText,ReplacementText,`r`n,`n, All
		}
		StringGetPos,CursorPoint,MeasurementText,`%|
		StringReplace, ReplacementText, ReplacementText, `%|,, All
		StringReplace, MeasurementText, MeasurementText, `%|,, All
		StringLen,ClipLength,MeasurementText
		ReturnTo := ClipLength - CursorPoint
	}

	if MODE = 0
	{
		if ReturnTo > 0
		{
			if ReplacementText contains !,#,^,+,{
			{
				WinActivate,%thisWindow%
				SendRaw, %ReplacementText%
				Send,{Left %ReturnTo%}
			}
			else
			{
				WinActivate,%thisWindow%
				Send,%ReplacementText%{Left %ReturnTo%}
			}
		}
		else
		{
			WinActivate,%thisWindow%
			SendRaw,%ReplacementText%
		}
	}
	else
	{
		oldClip = %Clipboard%
		Clipboard = %ReplacementText%
		if ReturnTo > 0
		{
			WinActivate,%thisWindow%
			Send,^v{Left %ReturnTo%}
		}
		else
		{
			WinActivate,%thisWindow%
			Send,^v
		}
		Clipboard = %oldClip%
	}
;	if ReturnTo > 0
;		Send, {Left %ReturnTo%}

}
SendMode Event
IniRead,expanded,texter.ini,Stats,Expanded
IniRead,chars_saved,texter.ini,Stats,Characters
expanded += 1
chars_saved += ClipLength
IniWrite,%expanded%,texter.ini,Stats,Expanded
IniWrite,%chars_saved%,texter.ini,Stats,Characters
Return

HOTKEYS: 
StringTrimLeft,hotkey,A_ThisHotkey,1 
StringLen,hotkeyl,hotkey 
If hotkeyl>1 
  hotkey=`{%hotkey%`} 
Send,{SC77}
Return 

ASSIGNVARS:
Version = 0.5
EnterCSV = %A_ScriptDir%\Active\bank\enter.csv
TabCSV = %A_ScriptDir%\Active\bank\tab.csv
SpaceCSV = %A_ScriptDir%\Active\bank\space.csv
ReplaceWAV = %A_ScriptDir%\resources\replace.wav
TexterPNG = %A_ScriptDir%\resources\texter.png
TexterICO = %A_ScriptDir%\resources\texter.ico
StyleCSS = %A_ScriptDir%\resources\style.css
return

READINI:
IfNotExist bank
	FileCreateDir, bank
IfNotExist replacements
	FileCreateDir, replacements
else
{
	IniRead,hexified,texter.ini,Settings,Hexified
	if hexified = ERROR
		Gosub,HexAll
}
IfNotExist resources
	FileCreateDir, resources
IfNotExist bundles
	FileCreateDir, bundles
IfNotExist Active
{
	FileCreateDir, Active
	FileCreateDir, Active\replacements
	FileCreateDir, Active\bank
}
IniWrite,%Version%,texter.ini,Preferences,Version
IniWrite,0,texter.ini,Settings,Disable
cancel := GetValFromIni("Cancel","Keys","{Escape}") ;keys to stop completion, remember {} 
ignore := GetValFromIni("Ignore","Keys","{Tab}`,{Enter}`,{Space}") ;keys not to send after completion 
IniWrite,{Escape}`,{Tab}`,{Enter}`,{Space}`,{Left}`,{Right}`,{Up}`,{Down},texter.ini,Autocomplete,Keys
keys := GetValFromIni("Autocomplete","Keys","{Escape}`,{Tab}`,{Enter}`,{Space}`,{Left}`,{Right}`,{Esc}`,{Up}`,{Down}")
otfhotkey := GetValFromIni("Hotkey","OntheFly","^+H")
managehotkey := GetValFromIni("Hotkey","Management","^+M")
disablehotkey := GetValFromIni("Hotkey", "Disable","")
MODE := GetValFromIni("Settings","Mode",0)
EnterBox := GetValFromIni("Triggers","Enter",0)
TabBox := GetValFromIni("Triggers","Tab",0)
SpaceBox := GetValFromIni("Triggers","Space",0)
ExSound := GetValFromIni("Preferences","ExSound",1)
Synergy := GetValFromIni("Preferences","Synergy",0)
AutoCorrect := GetValFromIni("Preferences","AutoCorrect",1)

;; Enable hotkeys for creating new keys and managing replacements
if otfhotkey <>
{
	Hotkey,IfWinNotActive,Texter Preferences
	Hotkey,%otfhotkey%,NEWKEY	
	Hotkey,IfWinActive
}
if managehotkey <>
{
	Hotkey,IfWinNotActive,Texter Preferences
	Hotkey,%managehotkey%,MANAGE
	Hotkey,IfWinActive
}

if disablehotkey <>
{
	Hotkey,IfWinNotActive,Texter Preferences
	Hotkey,%disablehotkey%,DISABLE
	Hotkey,IfWinActive
}


;; This section is intended to exit the input in the Start thread whenever the mouse is clicked or 
;; the user Alt-Tabs to another window so that Texter is prepared
~LButton::Send,{SC77}
$!Tab::
{
	GetKeyState,capsL,Capslock,T
	SetCapsLockState,Off
	pressed = 0
	Loop {
		Sleep,10
		GetKeyState,altKey,Alt,P
		GetKeyState,tabKey,Tab,P
		if (altKey = "D") and (tabKey = "D")
		{
			if pressed = 0
			{
				pressed = 1
				Send,{Alt down}{Tab}
				continue
			}
			else
			{
				continue
			}
		}
		else if (altKey = "D")
		{
			pressed = 0
			continue
		}
		else
		{
			Send,{Alt up}
			break
		}
	}
	Send,{SC77}
	if (capsL = "D")
		SetCapsLockState,On
}

$!+Tab::
{
	GetKeyState,capsL,Capslock,T
	SetCapsLockState,Off
	pressed = 0
	Loop {
		Sleep,10
		GetKeyState,altKey,Alt,P
		GetKeyState,tabKey,Tab,P
		GetKeyState,shiftKey,Shift,P
		if (altKey = "D") and (tabKey = "D") and (shiftKey = "D")
		{
			if pressed = 0
			{
				pressed = 1
				Send,{Alt down}{Shift down}{Tab}
				;Send,{Shift up}
				continue
			}
			else
			{
				continue
			}
		}
		else if (altKey = "D") and (shiftKey != "D")
		{
			pressed = 0
			Send,{Shift up}
			break
		}
		else if (altKey = "D") and (shiftKey = "D")
		{
			pressed = 0
			continue
		}
		else
		{
			Send,{Alt up}{Shift up}
			break
		}
	}
;	Send,{SC77}
	if (capsL = "D")
		SetCapsLockState,On
}
Return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Implementation and GUI for on-the-fly creation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NEWKEY:
if A_GuiControl = + ;;;; MAYBE CHANGE THIS TO IfWinExist,Texter Management
	GuiControlGet,CurrentBundle,,BundleTabs
else
	CurrentBundle =
if (CurrentBundle != "") and (CurrentBundle != "Default")
	AddToDir = Bundles\%CurrentBundle%\
else
	AddToDir = 
Gui,1: Destroy
IniRead,EnterBox,texter.ini,Triggers,Enter
IniRead,TabBox,texter.ini,Triggers,Tab
IniRead,SpaceBox,texter.ini,Triggers,Space
Gui,1: font, s12, Arial  
Gui,1: +owner2 +AlwaysOnTop -SysMenu +ToolWindow  ;suppresses taskbar button, always on top, removes minimize/close
Gui,1: Add, Text,x10 y20, Hotstring:
Gui,1: Add, Edit, x13 y45 r1 W65 vRString,
Gui,1: Add, Edit, x100 y45 r4 W395 vFullText, Enter your replacement text here...
Gui,1: Add, Text,x115,Trigger:
Gui,1: Add, Checkbox, vEnterCbox yp x175 Checked%EnterBox%, Enter
Gui,1: Add, Checkbox, vTabCbox yp x242 Checked%TabBox%, Tab
Gui,1: Add, Checkbox, vSpaceCbox yp x305 Checked%SpaceBox%, Space
Gui,1: font, s8, Arial 
Gui,1: Add, Button,w80 x320 default,&OK
Gui,1: Add, Button,w80 xp+90 GButtonCancel,&Cancel
Gui,1: font, s12, Arial  
Gui,1: Add,DropDownList,x100 y15 vTextOrScript, Text||Script
Gui,1: Add,Picture,x0 y105,%TexterPNG%
Gui 2:+Disabled
Gui,1: Show, W500 H200,Add new hotstring...
return

GuiEscape:
ButtonCancel:
Gui 2:-Disabled
Gui,1: Destroy
return

ButtonOK:
Gui,1: Submit, NoHide
Gui 1:+OwnDialogs
hexRString:=hexify(RString)
IfExist, %A_ScriptDir%\%AddToDir%replacements\%hexRString%.txt
{
	MsgBox,262144,Hotstring already exists, A replacement with the text %RString% already exists.  Would you like to try again?
	return
}
IsScript := (TextOrScript == "Script")

if SaveHotstring(RString, FullText, IsScript, AddToDir, SpaceCbox, TabCbox, EnterCbox)
{
	Gui 2:-Disabled
	Gui,1: Submit
}
Gosub,GetFileList
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; End Implementation and GUI for on-the-fly creation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



TRAYMENU:
Menu,TRAY,NoStandard 
Menu,TRAY,DeleteAll 
Menu,TRAY,Add,&Manage hotstrings,MANAGE
Menu,TRAY,Add,&Create new hotstring,NEWKEY
Menu,TRAY,Add
Menu,TRAY,Add,P&references...,PREFERENCES
Menu,TRAY,Add,&Import bundle,IMPORT
Menu,TRAY,Add,&Help,HELP
Menu,TRAY,Add
Menu,TRAY,Add,&About...,ABOUT
Menu,TRAY,Add,&Disable,DISABLE
if disable = 1
	Menu,Tray,Check,&Disable
Menu,TRAY,Add,E&xit,EXIT
Menu,TRAY,Default,&Manage hotstrings
Menu,Tray,Tip,Texter
Menu,TRAY,Icon,resources\texter.ico
Return

ABOUT:
Gui,4: Destroy
Gui,4: +owner2
Gui,4: Add,Picture,x200 y0,%TexterPNG%
Gui,4: font, s36, Courier New
Gui,4: Add, Text,x10 y35,Texter
Gui,4: font, s8, Courier New
Gui,4: Add, Text,x171 y77,%Version%
Gui,4: font, s9, Arial 
Gui,4: Add,Text,x10 y110 Center,Texter is a text replacement utility designed to save`nyou countless keystrokes on repetitive text entry by`nreplacing user-defined abbreviations (or hotstrings)`nwith your frequently-used text snippets.`n`nTexter is written by Adam Pash and distributed`nby Lifehacker under the GNU Public License.`nFor details on how to use Texter, check out the
Gui,4:Font,underline bold
Gui,4:Add,Text,cBlue gHomepage Center x110 y230,Texter homepage
Gui,4: Color,F8FAF0
Gui 2:+Disabled
Gui,4: Show,auto,About Texter
Return

DISABLE:
IniRead,disable,texter.ini,Settings,Disable
if disable = 0
{
	IniWrite,1,texter.ini,Settings,Disable
	EnableTriggers(false)
	Menu,Tray,Check,&Disable
}
else
{
	IniWrite,0,texter.ini,Settings,Disable
	EnableTriggers(true)
	Menu,Tray,Uncheck,&Disable
}
return

Homepage:
Run http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php
return

BasicUse:
Run http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php#basic
return

Scripting:
Run http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php#advanced
return

4GuiClose:
4GuiEscape:
DismissAbout:
Gui 2:-Disabled
Gui,4: Destroy
return

HELP:
Gui,5: Destroy
Gui,5: Add,Picture,x200 y5,%TexterPNG%
Gui,5: font, s36, Courier New
Gui,5: Add, Text,x20 y40,Texter
Gui,5: font, s9, Arial 
Gui,5: Add,Text,x19 y285 w300 center,All of Texter's documentation can be found online at the
Gui,5:Font,underline bold
Gui,5:Add,Text,cBlue gHomepage Center x125 y305,Texter homepage
Gui,5: font, s9 norm, Arial 
Gui,5: Add,Text,x10 y100 w300,For help by topic, click on one of the following:
Gui,5:Font,underline bold
Gui,5:Add,Text,x30 y120 cBlue gBasicUse,Basic Use: 
Gui,5:Font,norm
Gui,5:Add,Text,x50 y140 w280, Covers how to create basic text replacement hotstrings.
Gui,5:Font,underline bold
Gui,5:Add,Text,x30 y180 cBlue gScripting,Sending advanced keystrokes: 
Gui,5:Font,norm
Gui,5:Add,Text,x50 y200 w280, Texter is capable of sending advanced keystrokes, like keyboard combinations.  This section lists all of the special characters used in script creation, and offers a few examples of how you might use scripts.
Gui,5: Color,F8FAF0
Gui,5: Show,auto,Texter Help
Return

5GuiEscape:
DismissHelp:
Gui,5: Destroy
return

GetFileList:
FileList =
Loop, %A_ScriptDir%\replacements\*.txt
{
	thisFile:=Dehexify(A_LoopFileName)
	FileList = %FileList%%thisFile%|
}
StringReplace, FileList, FileList, .txt,,All
return

PREFERENCES:
Gui,3: Destroy
Gui,3: +owner2
Gui,3: Add, Tab,x5 y5 w306 h280,General|Print|Stats ;|Import|Export Add these later
IniRead,otfhotkey,texter.ini,Hotkey,OntheFly
Gui,3: Add,Text,x10 y40,On-the-Fly shortcut:
Gui,3: Add,Hotkey,xp+10 yp+20 w100 vsotfhotkey, %otfhotkey%
Gui,3: Add,Text,x150 y40,Hotstring Management shortcut:
IniRead,managehotkey,texter.ini,Hotkey,Management
Gui,3: Add,Hotkey,xp+10 yp+20 w100 vsmanagehotkey, %managehotkey%
Gui,3: Add,Text,x10 yp+25,Global disable shortcut:
IniRead,disablehotkey,texter.ini,Hotkey,Disable
Gui,3: Add,Hotkey,xp+10 yp+20 w100 vdisablehotkey,%disablehotkey%
;code optimization -- use mode value to set in initial radio values
CompatMode := NOT MODE
Gui,3: Add,Radio,x10 yp+30 vModeGroup Checked%CompatMode%,Compatibility mode (Default)
Gui,3: Add,Radio,Checked%MODE%,Clipboard mode (Faster, but less compatible)
OnStartup := GetValFromIni(Settings, Startup, false)
Gui,3: Add,Checkbox, vStartup x20 yp+30 Checked%OnStartup%,Run Texter at start up
IniRead,Update,texter.ini,Preferences,UpdateCheck
Gui,3: Add,Checkbox, vUpdate x20 yp+20 Checked%Update%,Check for updates at launch?
IniRead,AutoCorrect,texter.ini,Preferences,AutoCorrect
Gui,3: Add,Checkbox, vAutoCorrect x20 yp+20 gToggle Checked%AutoCorrect%,Enable Universal Spelling AutoCorrect?
IniRead,ExSound,texter.ini,Preferences,ExSound
Gui,3: Add,Checkbox, vExSound x20 yp+20 gToggle Checked%ExSound%,Play sound when replacement triggered?
IniRead,Synergy,texter.ini,Preferences,Synergy
Gui,3: Add,Checkbox, vSynergy x20 yp+20 gToggle Checked%Synergy%,Make Texter compatible across computers with Synergy?
;Gui,3: Add,Button,x150 y200 w75 GSETTINGSOK Default,&OK
Gui,3: Add,Button,x150 yp+30 w75 GSETTINGSOK Default,&OK
Gui,3: Add,Button,x230 yp w75 GSETTINGSCANCEL,&Cancel
Gui,3: Tab,2
Gui,3: Add,Button,w150 h150 gPrintableList,Create Printable Texter Cheatsheet
Gui,3: Add,Text,xp+160 y50 w125 Wrap,Click the big button to export a printable cheatsheet of all your Texter hotstrings, replacements, and triggers.
Gui,3: Tab,3
Gui,3: Add,Text,x10 y40,Your Texter stats:
IniRead,expanded,texter.ini,Stats,Expanded
Gui,3: Add,Text,x25 y60,Snippets expanded:   %expanded% 
IniRead,chars_saved,texter.ini,Stats,Characters
Gui,3: Add,Text,x25 y80,Characters saved:     %chars_saved%
SetFormat,FLOAT,0.2
time_saved := chars_saved/24000
Gui,3: Add,Text,x25 y100,Hours saved:             %time_saved% (assuming 400 chars/minute)
;Gui,3: Add,Button,x150 y200 w75 GSETTINGSOK Default,&OK
;Gui,3: Add,Button,x230 y200 w75 GSETTINGSCANCEL,&Cancel
Gui 2:+Disabled
Gui,3: Show,,Texter Preferences
Return

SETTINGSOK:
Gui,3: Submit, NoHide
If (sotfhotkey != otfhotkey)
{
	otfhotkey:=sotfhotkey
	If otfhotkey<>
	{
	  Hotkey,IfWinNotActive,Texter Preferences
	  Hotkey,%otfhotkey%,Newkey
	  HotKey,%otfhotkey%,On
	  Hotkey,IfWinActive
	}
	IniWrite,%otfhotkey%,texter.ini,Hotkey,OntheFly
}

If (smanagehotkey != managehotkey)
{
	managehotkey:=smanagehotkey
	If managehotkey<>
	{
	  Hotkey,IfWinNotActive,Texter Preferences
	  Hotkey,%managehotkey%,Manage
	  HotKey,%managehotkey%,On
	  Hotkey,IfWinActive
	}
	IniWrite,%managehotkey%,texter.ini,Hotkey,Management
}
IniWrite,%disablehotkey%,texter.ini,Hotkey,Disable
;code optimization -- calculate MODE from ModeGroup
MODE := ModeGroup - 1
IniWrite,%MODE%,texter.ini,Settings,Mode
IniWrite,%Update%,texter.ini,Preferences,UpdateCheck
If Startup = 1
{
	IfNotExist %A_StartMenu%\Programs\Startup\Texter.lnk
		;Get icon for shortcut link:
		;1st from compiled EXE
		if %A_IsCompiled%
		{
			IconLocation=%A_ScriptFullPath%
		}
		;2nd from icon in resources folder
		else IfExist %TexterICO%
		{
			IconLocation=%TexterICO%
		}
		;3rd from the AutoHotkey application itself
		else
		{
			IconLocation=%A_AhkPath%
		}
		;use %A_ScriptFullPath% instead of texter.exe
		;to allow compatibility with source version
		FileCreateShortcut,%A_ScriptFullPath%,%A_StartMenu%\Programs\Startup\Texter.lnk,%A_ScriptDir%,,Text replacement system tray application,%IconLocation%
}
else
{
	IfExist %A_StartMenu%\Programs\Startup\Texter.lnk
	{
		FileDelete %A_StartMenu%\Programs\Startup\Texter.lnk
	}
}
IniWrite,%Startup%,texter.ini,Settings,Startup
3GuiClose:
3GuiEscape:
SETTINGSCANCEL:
Gui 2:-Disabled
Gui,3: Destroy

Return

TOGGLE:
GuiControlGet,ToggleValue,,%A_GuiControl%
IniWrite,%ToggleValue%,texter.ini,Preferences,%A_GuiControl%
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Implementation and GUI for management ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MAINWINTOOLBAR:
Menu, ToolsMenu, Add, P&references..., Preferences
Menu, MgmtMenuBar, Add, &Tools, :ToolsMenu
Menu, BundlesMenu, Add, &Export, Export
Menu, BundlesMenu, Add, &Import, Import
Menu, BundlesMenu, Add, &Add, AddBundle
Menu, BundlesMenu, Add, &Remove, DeleteBundle
Menu, MgmtMenuBar, Add, &Bundles, :BundlesMenu
Menu, HelpMenu, Add, &Basic Use, BasicUse
Menu, HelpMenu, Add, Ad&vanced Use, Scripting
Menu, HelpMenu, Add, &Homepage, Homepage
Menu, HelpMenu, Add, &About..., About
Menu, MgmtMenuBar, Add, &Help, :HelpMenu
Gui,2: Menu, MgmtMenuBar
return

MANAGE:
Gui,2: Destroy
Gosub,MAINWINTOOLBAR
GoSub,GetFileList
Bundles =
Loop,bundles\*,2
{
	Bundles = %Bundles%|%A_LoopFileName%
	thisBundle = %A_LoopFileName%
;	Loop,bundles\%A_LoopFileName%\replacements\*.txt
;	{
;		thisReplacement:=Dehexify(A_LoopFileName)
;		thisBundle = %thisBundle%%thisReplacement%|
;	}
	StringReplace, thisBundle, thisBundle, .txt,,All
	StringReplace, thisBundle, thisBundle, %A_LoopFileName%,,
	%A_LoopFileName% = %thisBundle%
}
StringReplace, FileList, FileList, .txt,,All
StringTrimLeft,Bundles,Bundles,1
Gui,2: Default
Gui,2: Font, s12, Arial
Gui,2: Add,Tab,x5 y5 h390 w597 vBundleTabs gListBundle,Default|%Bundles% ;;;;;; START ADDING BUNDLES
Gui,2: Add, Text, Section,
Gui,2: Tab ;;; Every control after this point belongs to no individual tab
Gui,2: Add, Text,ys xs,Hotstring:
Gui,2: Add, ListBox, xs r15 W100 vChoice gShowString Sort, %FileList%
Gui,2: Add, Button, w35 xs+10 GAdd,+
Gui,2: Add, Button, w35 xp+40 GDelete,-
Gui,2: Add, DropDownList, Section ys vTextOrScript, Text||Script
Gui,2: Font, s12, Arial
Gui,2: Add, Edit, r12 W460 xs vFullText
Gui,2: Add, Text, xs,Trigger:
Gui,2: Add, Checkbox, vEnterCbox yp xp+65, Enter
Gui,2: Add, Checkbox, vTabCbox yp xp+65, Tab
Gui,2: Add, Checkbox, vSpaceCbox yp xp+60, Space
Gui,2: Font, s8, Arial
Gui,2: Add,Button, w80 GPButtonSave xs+375 yp, &Save
IniRead,bundleCheck,texter.ini,Bundles,Default
Gui,2: Add, Checkbox, Checked%bundleCheck% vbundleCheck gToggleBundle xs+400 yp+50,Enabled
Gui,2: Add, Button, w80 Default GPButtonOK xs+290 yp+30,&OK
Gui,2: Add, Button, w80 xp+90 GPButtonCancel, &Cancel
Gui,2: Show, , Texter Management
Hotkey,IfWinActive, Texter Management
Hotkey,!p,Preferences
Hotkey,delete,Delete
Hotkey,IfWinActive
return

ListBundle:
if A_GuiControl = BundleTabs
	GuiControlGet,CurrentBundle,2:,BundleTabs
IniRead,bundleCheck,texter.ini,Bundles,%CurrentBundle%
GuiControl,2:,Choice,|
Loop,bundles\*,2
{
	Bundles = %Bundles%|%A_LoopFileName%
	thisBundle = %A_LoopFileName%
	Loop,bundles\%A_LoopFileName%\replacements\*.txt
	{
		thisReplacement:=Dehexify(A_LoopFileName)
		thisBundle = %thisBundle%%thisReplacement%|
	}
;	StringReplace, thisBundle, thisBundle, .txt,,All
	StringReplace, thisBundle, thisBundle, %A_LoopFileName%,,
	%A_LoopFileName% = %thisBundle%
}
;if A_GuiControl = Tab
;	GuiControl,,Choice,|
;else
;	GuiControl,,Choice,%RString%||
GuiControl,2:,FullText,
GuiControl,2:,EnterCbox,0
GuiControl,2:,TabCbox,0
GuiControl,2:,SpaceCbox,0
GuiControl,2:,bundleCheck,%bundleCheck%
if CurrentBundle = Default
{
	Gosub,GetFileList
	CurrentBundle = %FileList%
	GuiControl,,Choice,%CurrentBundle%
}
else
{
	StringTrimLeft,CurrentBundle,%CurrentBundle%,0
	GuiControl,2:,Choice,%CurrentBundle%
}
return

ToggleBundle:
GuiControlGet,CurrentBundle,,BundleTabs
GuiControlGet,bundleCheck,,bundleCheck
IniWrite,%bundleCheck%,texter.ini,Bundles,%CurrentBundle%
Gosub,BuildActive
return

BuildActive:
activeBundles =
FileDelete,Active\replacements\*
FileDelete,Active\bank\*
Loop,bundles\*,2
{
	IniRead,activeCheck,texter.ini,Bundles,%A_LoopFileName%
	if activeCheck = 1
		activeBundles = %activeBundles%%A_LoopFileName%,
}
IniRead,activeCheck,texter.ini,Bundles,Default
if activeCheck = 1
	activeBundles = %activeBundles%Default
Loop,Parse,activeBundles,CSV
{
;	MsgBox,%A_LoopField%
	if A_LoopField = Default
	{
		FileCopy,replacements\*.txt,Active\replacements
		FileRead,tab,bank\tab.csv
		FileAppend,%tab%,Active\bank\tab.csv
		FileRead,space,bank\space.csv
		FileAppend,%space%,Active\bank\space.csv
		FileRead,enter,bank\enter.csv
		FileAppend,%enter%,Active\bank\enter.csv
	}
	else
	{
		FileCopy,Bundles\%A_LoopField%\replacements\*.txt,active\replacements
		FileRead,tab,Bundles\%A_LoopField%\bank\tab.csv
		FileAppend,%tab%,active\bank\tab.csv
		FileRead,space,Bundles\%A_LoopField%\bank\space.csv
		FileAppend,%space%,active\bank\space.csv
		FileRead,enter,Bundles\%A_LoopField%\bank\enter.csv
		FileAppend,%enter%,active\bank\enter.csv
	}
;		IfExist active\replacements\wc.txt
;			MsgBox,%A_LoopFileName% put me here
}
FileRead, EnterKeys, %A_WorkingDir%\Active\bank\enter.csv
FileRead, TabKeys, %A_WorkingDir%\Active\bank\tab.csv
FileRead, SpaceKeys, %A_WorkingDir%\Active\bank\space.csv
ActiveList =
Loop, Active\replacements\*.txt
{
	ActiveList = %ActiveList%%A_LoopFileName%|
}
StringReplace, ActiveList, ActiveList, .txt,,All

return

ADD:
EnableTriggers(false)
GoSub,Newkey
IfWinExist,Add new hotstring...
{
	WinWaitClose,Add new hotstring...,,
}
;GoSub,GetFileList
GoSub,ListBundle
StringReplace, CurrentBundle, CurrentBundle,|%RString%|,|%RString%||
GuiControl,,Choice,|%CurrentBundle%
EnableTriggers(true)
GoSub,ShowString
return

DELETE:
Gui 2:+OwnDialogs
GuiControlGet,ActiveChoice,,Choice
GuiControlGet,CurrentBundle,,BundleTabs
if (CurrentBundle != "") and (CurrentBundle != "Default")
	RemoveFromDir = Bundles\%CurrentBundle%\
else
	RemoveFromDir = 

MsgBox,1,Confirm Delete,Are you sure you want to delete this hotstring: %ActiveChoice%
IfMsgBox, OK
{
	ActiveChoice:=Hexify(ActiveChoice)
	FileDelete,%A_ScriptDir%\%RemoveFromDir%replacements\%ActiveChoice%.txt
	DelFromBank(ActiveChoice, RemoveFromDir, "enter")
	DelFromBank(ActiveChoice, RemoveFromDir, "tab")
	DelFromBank(ActiveChoice, RemoveFromDir, "space")
	GoSub,ListBundle
	Gosub,BuildActive
	GuiControl,,Choice,|%CurrentBundle%
	GuiControl,,FullText,
	GuiControl,,EnterCbox,0
	GuiControl,,TabCbox,0
	GuiControl,,SpaceCbox,0
}
return

ShowString:
GuiControlGet,ActiveChoice,,Choice
ActiveChoice:=Hexify(ActiveChoice)
GuiControlGet,CurrentBundle,,BundleTabs
if CurrentBundle = Default
	ReadFrom = 
else
	ReadFrom = bundles\%CurrentBundle%\

FileRead,enter,%ReadFrom%bank\enter.csv
FileRead,tab,%ReadFrom%bank\tab.csv
FileRead,space,%ReadFrom%bank\space.csv

if ActiveChoice in %enter%
{
	GuiControl,,EnterCbox,1
}
else
	GuiControl,,EnterCbox,0
if ActiveChoice in %tab%
{
	GuiControl,,TabCbox,1
}
else
	GuiControl,,TabCbox,0
if ActiveChoice in %space%
{
	GuiControl,,SpaceCbox,1
}
else
	GuiControl,,SpaceCbox,0
FileRead, Text, %ReadFrom%replacements\%ActiveChoice%.txt
IfInString,Text,::scr::
{
	GuiControl,,TextOrScript,|Text|Script||
	StringReplace,Text,Text,::scr::,,
}
else
	GuiControl,,TextOrScript,|Text||Script
GuiControl,,FullText,%Text%
return

PButtonSave:
Gui,2: Submit, NoHide
IsScript := (TextOrScript == "Script")

If Choice <>
{
	if (CurrentBundle != "") and (CurrentBundle != "Default")
		SaveToDir = Bundles\%CurrentBundle%\
	else
		SaveToDir = 
	PSaveSuccessful := SaveHotstring(Choice, FullText, IsScript, SaveToDir, SpaceCbox, TabCbox, EnterCbox)
}
else
{
	PSaveSuccessful = true
}
return

2GuiEscape:
PButtonCancel:
Gui,2: Destroy
return

PButtonOK:
Gosub,PButtonSave
if PSaveSuccessful
{
	Gui,2: Submit
	Gui,2: Destroy
}
return

AddBundle:
EnableTriggers(false)
Hotkey,IfWinActive,New Bundle
Hotkey,Space,NOSPACE
Hotkey,IfWinActive
InputBox,BundleName,New Bundle,What would you like to call your bundle? (no spaces),,160,150,,,
if ErrorLevel
{
	EnableTriggers(true)
	return
}
else
{
	IfExist bundles\%BundleName%
		MsgBox,,Bundle already in use,%BundleName% bundle already exists.`nChoose another name or delete the current %BundleName% bundle.
	else
	{
		FileCreateDir,bundles\%BundleName%
		FileCreateDir,bundles\%BundleName%\replacements
		FileCreateDir,bundles\%BundleName%\bank
		IniWrite,1,texter.ini,Bundles,%BundleName%
		Bundles =
		Loop,bundles\*,2
		{
			Bundles = %Bundles%|%A_LoopFileName%
			;thisBundle = %A_LoopFileName%
			if BundleName = %A_LoopFileName%
				Bundles = %Bundles%|
		}
		GuiControl,,BundleTabs,|Default|%Bundles%
		GuiControl,,Choice,|
	}
}
EnableTriggers(true)
return

NOSPACE:
Msgbox,0,Oops...,Whoops... Bundle names must not have any spaces.
return

DeleteBundle:
GuiControlGet,CurrentBundle,,BundleTabs
if CurrentBundle = Default
{
	MsgBox,You can't remove the Default bundle.
	return
}
MsgBox,4,Confirm bundle delete,Are you sure you want to remove the %CurrentBundle% bundle?
IfMsgBox, Yes
{
	FileRemoveDir,bundles\%CurrentBundle%,1
	Bundles =
	Loop,bundles\*,2
	{
		Bundles = %Bundles%|%A_LoopFileName%
	}
	GuiControl,,BundleTabs,|Default|%Bundles%
	Gosub,GetFileList
	GuiControl,,Choice,%FileList%
}
return

EXPORT:
GuiControlGet,CurrentBundle,,BundleTabs
MsgBox,4,Confirm Bundle Export,Are you sure you want to export the %CurrentBundle% bundle?
IfMsgBox, Yes
{
	IfNotExist %A_WorkingDir%\Texter Export
		FileCreateDir,%A_WorkingDir%\Texter Exports
	FileDelete,Texter Exports\%CurrentBundle%.texter
	IniWrite,%CurrentBundle%,Texter Exports\%CurrentBundle%.texter,Info,Name
	if (CurrentBundle = "Default")
		BundleDir = 
	else
		BundleDir = bundles\%CurrentBundle%\
	Loop,%BundleDir%replacements\*,0
	{
		FileRead,replacement,%A_LoopFileFullPath%
		IfInString,replacement,`r`n
			StringReplace,replacement,replacement,`r`n,`%bundlebreak,All
		IniWrite,%A_LoopFileName%,Texter Exports\%CurrentBundle%.texter,%A_Index%,Hotstring
		IniWrite,%replacement%,Texter Exports\%CurrentBundle%.texter,%A_Index%,Replacement
	}
	MsgBox,4,Your bundle was successfully created!,Congratulations, your bundle was successfully exported!`nYou can now share your bundle with the world by sending them the %CurrentBundle%.texter file.`nThey can add it to Texter through the import feature. `n`nWould you like to see the %CurrentBundle% bundle?
IfMsgBox, Yes
	Run,Texter Exports\
}

return

IMPORT:
FileSelectFile, ImportBundle,,, Import Texter bundle, *.texter
if ErrorLevel = 0
{
	IniRead,BundleName,%ImportBundle%,Info,Name
	IfExist bundles\%BundleName%
	{
		MsgBox,4,%BundleName% bundle already installed,%BundleName% bundle already installed.`nWould you like to overwrite previous %BundleName% bundle?
		IfMsgBox, No
			return
		else
		{
			FileRemoveDir,bundles\%BundleName%,1
		}
	}
	FileCreateDir,bundles\%BundleName%
	FileCreateDir,bundles\%BundleName%\replacements
	FileCreateDir,bundles\%BundleName%\bank
	
	Loop
	{
		IniRead,file,%ImportBundle%,%A_Index%,Hotstring
		IniRead,replacement,%ImportBundle%,%A_Index%,Replacement
		StringReplace, hotstring, file, .txt
		StringReplace,replacement,replacement,`%bundlebreak,`r`n,All
		bundleCollection = %hotstring%,%bundleCollection%
		if file = ERROR
				break
		else
			FileAppend,%replacement%,bundles\%BundleName%\replacements\%file%
	}
	Gui, 8: Add, Text, Section x10 y10,What triggers would you like to use with the %BundleName% bundle?
	Gui,8: Add, Checkbox, vEnterCbox x30, Enter
	Gui,8: Add, Checkbox, vTabCbox yp xp+65, Tab
	Gui,8: Add, Checkbox, vSpaceCbox yp xp+60, Space
	Gui,8: Add,Button, x180 Default w80 GCreateBank,&OK
	Gui, 8: Show,,Set default triggers
}
return

CreateBank:
Gui,8: Submit
Gui,8: Destroy
if EnterCbox = 1
	FileAppend,%bundleCollection%,bundles\%BundleName%\bank\enter.csv
if TabCbox = 1
	FileAppend,%bundleCollection%,bundles\%BundleName%\bank\tab.csv
if SpaceCbox = 1
	FileAppend,%bundleCollection%,bundles\%BundleName%\bank\space.csv
MsgBox,4,Enable %BundleName% bundle?,Would you like to enable the %BundleName% bundle?
IfMsgBox,Yes
{
	IniWrite,1,texter.ini,Bundles,%BundleName%
	Gosub,BuildActive
}
else
	IniWrite,0,texter.ini,Bundles,%BundleName%
Bundles =
Loop,bundles\*,2
{
	Bundles = %Bundles%%A_LoopFileName%|
	;thisBundle = %A_LoopFileName%
	if BundleName = %A_LoopFileName%
		Bundles = %Bundles%|
}
GuiControl,2:,BundleTabs,|Default|%Bundles%
Gosub,ListBundle
return

;; method written by Dustin Luck for writing to ini
GetValFromIni(section, key, default)
{
	IniRead,IniVal,texter.ini,%section%,%key%
	if IniVal = ERROR
	{
		IniWrite,%default%,texter.ini,%section%,%key%
		IniVal := default
	}
	return IniVal
}

SaveHotstring(HotString, Replacement, IsScript, Bundle, SpaceIsTrigger, TabIsTrigger, EnterIsTrigger)
{
global EnterCSV
global TabCSV
global SpaceCSV
global EnterKeys
global TabKeys
global SpaceKeys
	HotString:=Hexify(HotString)
	successful := false
	if (!EnterIsTrigger AND !TabIsTrigger AND !SpaceIsTrigger)
	{
		MsgBox,262144,Choose a trigger,You need to choose a trigger in order to save a hotstring replacement.
	}
	else if (HotString <> "" AND Replacement <> "")
	{
		successful := true
		if IsScript
		{
			Replacement = ::scr::%Replacement%
		}

		IniWrite,%SpaceIsTrigger%,texter.ini,Triggers,Space
		IniWrite,%TabIsTrigger%,texter.ini,Triggers,Tab
		IniWrite,%EnterIsTrigger%,texter.ini,Triggers,Enter

		FileDelete, %A_ScriptDir%\%Bundle%replacements\%HotString%.txt
		FileAppend,%Replacement%,%A_ScriptDir%\%Bundle%replacements\%HotString%.txt

		if EnterIsTrigger
		{
			AddToBank(HotString, Bundle, "enter")
		}
		else
		{
			DelFromBank(HotString, Bundle, "enter")
		}
		if TabIsTrigger
		{
			AddToBank(HotString, Bundle, "tab")
		}
		else
		{
			DelFromBank(HotString, Bundle, "tab")
		}
		if SpaceIsTrigger
		{
			AddToBank(HotString, Bundle, "space")
		}
		else
		{
			DelFromBank(HotString, Bundle, "space")
		}
	}
	GoSub,BuildActive
	return successful
}

AddToBank(HotString, Bundle, Trigger)
{
	;HotString:=Dehexify(HotString)
	BankFile = %Bundle%bank\%trigger%.csv
	FileRead, Bank, %BankFile%
	if HotString not in %Bank%
	{
		FileAppend,%HotString%`,, %BankFile%
		FileRead, Bank, %BankFile%
	}
}

DelFromBank(HotString, Bundle, Trigger)
{
	BankFile = %Bundle%bank\%trigger%.csv
	FileRead, Bank, %BankFile%
	;HotString:=Dehexify(HotString)
	if HotString in %Bank%
	{
		StringReplace, Bank, Bank, %HotString%`,,,All
		FileDelete, %BankFile%
		FileAppend,%Bank%, %BankFile%
	}
}

EnableTriggers(doEnable)
{
global keys
	StringReplace,tempKeys,keys,`}`,`{,`n,All
	Loop,Parse,TempKeys,`n,`{`} 
	{
		if (doEnable)
		{
			Hotkey,IfWinNotActive,Enter desired text
			Hotkey,$%A_LoopField%,HOTKEYS
			Hotkey,$%A_LoopField%,On
			Hotkey,IfWinActive
		}
		else
		{
			Hotkey,IfWinNotActive,Enter desired text
			Hotkey,$%A_LoopField%,Off
			Hotkey,IfWinActive
		}
	}
}

RESOURCES:
;code optimization -- removed IfNotExist tests
;redundant when final arg to FileInstall is 0
FileInstall,resources\texter.ico,%TexterICO%,1
FileInstall,resources\replace.wav,%ReplaceWAV%,0
FileInstall,resources\texter.png,%TexterPNG%,1
FileInstall,resources\style.css,%StyleCSS%,0
return

;AUTOCLOSE:
;:*?B0:(::){Left}
;:*?B0:[::]{Left}
;:*?B0:{::{}}{Left}
;return

PrintableList:
alt := 0
List = <html xmlns="http://www.w3.org/1999/xhtml"><head><link type="text/css" href="style.css" rel="stylesheet"><title>Texter Hotstrings and Replacement Text Cheatsheet</title></head><body><h2>Texter Hostrings and Replacement Text Cheatsheet</h2><h2 style="color:red">Default</h2><span class="hotstring" style="border:none`; color:black`;"><h3>Hotstring</h3></span><span class="replacement" style="border:none`;"><h3>Replacement Text</h3></span><span class="trigger" style="border:none`;"><h3>Trigger(s)</h3></span>
Loop, replacements\*.txt
{
	alt := 1 - alt
	trig =
	hs = %A_LoopFileName%
	StringReplace, hs, hs, .txt
	FileRead, rp, replacements\%hs%.txt
	FileRead, entertrig, bank\enter.csv
	FileRead, tabtrig, bank\tab.csv
	FileRead, spacetrig, bank\space.csv
	If hs in %entertrig%
		trig = Enter
	If hs in %tabtrig%
		trig = %trig% Tab
	If hs in %spacetrig%
		trig = %trig% Space
	StringReplace, rp, rp, <,&lt;,All
	StringReplace, rp, rp, >,&gt;,All
	hs := DeHexify(hs)
	List = %List%<div class="row%alt%"><span class="hotstring">%hs%</span><span class="replacement">%rp%</span><span class="trigger">%trig%</span></div><br />
	
}
Loop,bundles\*,2
{
	thisBundle = %A_LoopFileName%
	List = %List%<br><br><br><h2 style="color:red; clear:both;">%thisBundle%</h2><span class="hotstring" style="border:none`; color:black`;"><h3>Hotstring</h3></span><span class="replacement" style="border:none`;"><h3>Replacement Text</h3></span><span class="trigger" style="border:none`;"><h3>Trigger(s)</h3></span>
	Loop,bundles\%A_LoopFileName%\replacements\*.txt
	{
		trig =
		hs = %A_LoopFileName%
		StringReplace, hs, hs, .txt
		FileRead, rp, bundles\%thisBundle%\replacements\%hs%.txt
		FileRead, entertrig, bundles\%thisBundle%\bank\enter.csv
		FileRead, tabtrig, bundles\%thisBundle%\bank\tab.csv
		FileRead, spacetrig, bundles\%thisBundle%\bank\space.csv
		If hs in %entertrig%
			trig = Enter
		If hs in %tabtrig%
			trig = %trig% Tab
		If hs in %spacetrig%
			trig = %trig% Space
		StringReplace, rp, rp, <,&lt;,All
		StringReplace, rp, rp, >,&gt;,All
		hs := DeHexify(hs)
		List = %List%<div class="row%alt%"><span class="hotstring">%hs%</span><span class="replacement">%rp%</span><span class="trigger">%trig%</span></div><br />
	}
	StringReplace, thisBundle, thisBundle, .txt,,All
	StringReplace, thisBundle, thisBundle, %A_LoopFileName%,,
	%A_LoopFileName% = %thisBundle%
} 
List = %List%</body></html>
IfExist resources\Texter Replacement Guide.html
	FileDelete,resources\Texter Replacement Guide.html
FileAppend,%List%, resources\Texter Replacement Guide.html
Run,resources\Texter Replacement Guide.html
return

UpdateCheck: ;;;;;;; Update the version number on each new release ;;;;;;;;;;;;;
IfNotExist texter.ini 
{
	MsgBox,4,Check for Updates?,Would you like to automatically check for updates when on startup?
	IfMsgBox,Yes
		updatereply = 1
	else
		updatereply = 0
}
update := GetValFromIni("Preferences","UpdateCheck",updatereply)
IniWrite,%Version%,texter.ini,Preferences,Version
if (update = 1)
	SetTimer,RunUpdateCheck,10000
return

RunUpdateCheck:
update("texter")
return

update(program) {
	SetTimer, RunUpdateCheck, Off
	UrlDownloadToFile,http://svn.adampash.com/%program%/CurrentVersion.txt,VersionCheck.txt
	if ErrorLevel = 0
	{
		FileReadLine, Latest, VersionCheck.txt,1
		IniRead,Current,%program%.ini,Preferences,Version
		;MsgBox,Latest: %Latest% `n Current: %Current%
		if (Latest > Current)
		{
			MsgBox,4,A new version of %program% is available!,Would you like to visit the %program% homepage and download the latest version?
			IfMsgBox,Yes
				Goto,Homepage
		}
		FileDelete,VersionCheck.txt ;; delete version check
	}
}

textPrompt(thisText) {
	Gui,7: +AlwaysOnTop -SysMenu +ToolWindow
	Gui,7: Add,Text,x5 y5, Enter the text you want to insert:
	Gui,7: Add,Edit,x20 y25 r1 vpromptText
	Gui,7: Add,Text,x5 y50,Your text will be replace the `%p variable:
	Gui,7: Add,Text,w300 Wrap x20 y70,%thisText%
	Gui,7: Show,auto,Enter desired text
	Hotkey,IfWinActive,Enter desired text
	Hotkey,Enter,SubmitPrompt
	;Hotkey,Space,
	WinWaitClose,Enter desired text
}
return

SubmitPrompt:
Gui, 7: Submit
Gui, 7: Destroy
StringReplace,ReplacementText,ReplacementText,`%p,%promptText%
return


HexAll:
;MsgBox,Hexing time!
FileCopyDir,replacements,resources\backup\replacements
FileCopyDir,bank,resources\backup\bank
Loop, %A_ScriptDir%\replacements\*.txt
{
	StringReplace, thisFile, A_LoopFileName, .txt,,All
	thisFile:=Hexify(thisFile)
	;MsgBox,% thisFile
	FileMove,%A_ScriptDir%\replacements\%A_LoopFileName%,%A_ScriptDir%\replacements\%thisFile%.txt
}
Loop, %A_ScriptDir%\bank\*.csv
{
	FileRead,thisBank,%A_ScriptDir%\bank\%A_LoopFileName%
	Loop,Parse,thisBank,CSV
	{
		thisString:=Hexify(A_LoopField)

		hexBank = %hexBank%%thisString%,
	}
	FileDelete,%A_ScriptDir%\bank\%A_LoopFileName%
	FileAppend,%hexBank%,%A_ScriptDir%\bank\%A_LoopFileName%
}
;TODO: Also hexify .csv files

IniWrite,1,texter.ini,Settings,Hexified
IniWrite,1,texter.ini,Bundles,Default
return

AUTOCORRECT:
#Hotstring R
#Hotstring *
::abandonned::abandoned
::abbout::about
::aberation::aberration
::abilties::abilities
::abilty::ability
::abondon::abandon
::abondoned::abandoned
::abondoning::abandoning
::abondons::abandons
::aborigene::aborigine
::abortificant::abortifacient
::abotu::about
::abouta::about a
::aboutit::about it
::aboutthe::about the
::abreviated::abbreviated
::abreviation::abbreviation
::abritrary::arbitrary
::abscence::absence
::absense::absence
::absolutly::absolutely
::absorbsion::absorption
::absorbtion::absorption
::abundacies::abundances
::abundancies::abundances
::abundunt::abundant
::abutts::abuts
::acadamy::academy
::acadmic::academic
::accademic::academic
::accademy::academy
::acccused::accused
::accelleration::acceleration
::acceptence::acceptance
::acceptible::acceptable
::accesories::accessories
::accessable::accessible
::accidant::accident
::accidentaly::accidentally
::accidently::accidentally
::acclimitization::acclimatization
::accomadate::accommodate
::accomadated::accommodated
::accomadates::accommodates
::accomadating::accommodating
::accomadation::accommodation
::accomadations::accommodations
::accomdate::accommodate
::accomodate::accommodate
::accomodated::accommodated
::accomodates::accommodates
::accomodating::accommodating
::accomodation::accommodation
::accomodations::accommodations
::accompanyed::accompanied
::accordeon::accordion
::accordian::accordion
::accordingto::according to
::accoring::according
::accoustic::acoustic
::accoutn::account
::accquainted::acquainted
::accross::across
::accussed::accused
::acedemic::academic
::acheive::achieve
::acheived::achieved
::acheivement::achievement
::acheivements::achievements
::acheives::achieves
::acheiving::achieving
::acheivment::achievement
::acheivments::achievements
::achievment::achievement
::achievments::achievements
::achive::achieve
::achivement::achievement
::achivements::achievements
::acknowldeged::acknowledged
::acknowledgeing::acknowledging
::acn::can
::acommodate::accommodate
::acomodate::accommodate
::acomplish::accomplish
::acomplished::accomplished
::acomplishment::accomplishment
::acomplishments::accomplishments
::acording::according
::acordingly::accordingly
::acquaintence::acquaintance
::acquaintences::acquaintances
::acquiantence::acquaintance
::acquiantences::acquaintances
::acquited::acquitted
::activites::activities
::activly::actively
::actualy::actually
::actualyl::actually
::acuracy::accuracy
::acused::accused
::acustom::accustom
::acustommed::accustomed
::adaption::adaptation
::adaptions::adaptations
::adavanced::advanced
::adbandon::abandon
::additinal::additional
::additinally::additionally
::addmission::admission
::addopt::adopt
::addopted::adopted
::addoptive::adoptive
::addresable::addressable
::addresed::addressed
::addresing::addressing
::addressess::addresses
::addtion::addition
::addtional::additional
::adecuate::adequate
::adequit::adequate
::adequite::adequate
::adhearing::adhering
::adherance::adherence
::admendment::amendment
::admininistrative::administrative
::adminstered::administered
::adminstrate::administrate
::adminstration::administration
::adminstrative::administrative
::adminstrator::administrator
::admissability::admissibility
::admissable::admissible
::admited::admitted
::admitedly::admittedly
::adn::and
::adolecent::adolescent
::adquire::acquire
::adquired::acquired
::adquires::acquires
::adquiring::acquiring
::adres::address
::adresable::addressable
::adresing::addressing
::adress::address
::adressable::addressable
::adressed::addressed
::advanage::advantage
::adventrous::adventurous
::advertisment::advertisement
::advertisments::advertisements
::advesary::adversary
::adviced::advised
::aeriel::aerial
::aeriels::aerials
::afair::affair
::afficianados::aficionados
::afficionado::aficionado
::afficionados::aficionados
::affilate::affiliate
::affilliate::affiliate
::affraid::afraid
::aforememtioned::aforementioned
::afterthe::after the
::againnst::against
::agains::against
::againstt he::against the
::agaisnt::against
::aganist::against
::aggaravates::aggravates
::aggreed::agreed
::aggreement::agreement
::aggregious::egregious
::aggresive::aggressive
::agian::again
::agianst::against
::agin::again
::aginst::against
::agravate::aggravate
::agre::agree
::agred::agreed
::agreeement::agreement
::agreemeent::agreement
::agreemeents::agreements
::agreemnet::agreement
::agreemnets::agreements
::agreemnt::agreement
::agregate::aggregate
::agregates::aggregates
::agreing::agreeing
::agression::aggression
::agressive::aggressive
::agressively::aggressively
::agressor::aggressor
::agricuture::agriculture
::agrieved::aggrieved
::ahev::have
::ahppen::happen
::ahve::have
::aicraft::aircraft
::aiport::airport
::airbourne::airborne
::aircaft::aircraft
::aircrafts::aircraft
::airporta::airports
::airrcraft::aircraft
::aisian::asian
::albiet::albeit
::alchohol::alcohol
::alchoholic::alcoholic
::alchol::alcohol
::alcholic::alcoholic
::alcohal::alcohol
::alcoholical::alcoholic
::aledge::allege
::aledged::alleged
::aledges::alleges
::alege::allege
::aleged::alleged
::alegience::allegiance
::algebraical::algebraic
::algorhitms::algorithms
::algoritm::algorithm
::algoritms::algorithms
::alientating::alienating
::alledge::allege
::alledged::alleged
::alledgedly::allegedly
::alledges::alleges
::allegedely::allegedly
::allegedy::allegedly
::allegely::allegedly
::allegence::allegiance
::allegience::allegiance
::allign::align
::alligned::aligned
::alliviate::alleviate
::allopone::allophone
::allopones::allophones
::allready::already
::allthough::although
::alltime::all-time
::allwasy::always
::allwyas::always
::almots::almost
::almsot::almost
::alochol::alcohol
::alomst::almost
::alot::a lot
::alotted::allotted
::alowed::allowed
::alowing::allowing
::alraedy::already
::alreayd::already
::alreday::already
::alse::else
::alsot::also
::alternitives::alternatives
::altho::although
::althought::although
::altough::although
::alwasy::always
::alwats::always
::alway::always
::alwyas::always
::amalgomated::amalgamated
::amatuer::amateur
::amde::made
::amendmant::amendment
::Ameria::America
::amerliorate::ameliorate
::amke::make
::amkes::makes
::amking::making
::ammend::amend
::ammended::amended
::ammendment::amendment
::ammendments::amendments
::ammount::amount
::ammused::amused
::amost::almost
::amoung::among
::amoungst::amongst
::amung::among
::analagous::analogous
::analitic::analytic
::analogeous::analogous
::anarchim::anarchism
::anarchistm::anarchism
::anbd::and
::ancestory::ancestry
::ancilliary::ancillary
::andone::and one
::androgenous::androgynous
::androgeny::androgyny
::andt he::and the
::andteh::and the
::andthe::and the
::anihilation::annihilation
::aniversary::anniversary
::anmd::and
::annoint::anoint
::annointed::anointed
::annointing::anointing
::annoints::anoints
::annouced::announced
::annualy::annually
::annuled::annulled
::anohter::another
::anomolies::anomalies
::anomolous::anomalous
::anomoly::anomaly
::anonimity::anonymity
::anoter::another
::anothe::another
::anounced::announced
::ans::and
::ansalisation::nasalisation
::ansalization::nasalization
::ansestors::ancestors
::antartic::antarctic
::anthromorphization::anthropomorphization
::anual::annual
::anulled::annulled
::anwsered::answered
::anyhwere::anywhere
::anyother::any other
::anythign::anything
::anyting::anything
::anytying::anything
::anywya::anyway
::aparent::apparent
::aparment::apartment
::apenines::apennines
::aplication::application
::aplied::applied
::apolegetics::apologetics
::apparant::apparent
::apparantly::apparently
::apparrent::apparent
::appart::apart
::appartment::apartment
::appartments::apartments
::appeareance::appearance
::appearence::appearance
::appearences::appearances
::appeares::appears
::appenines::apennines
::apperance::appearance
::apperances::appearances
::applicaiton::application
::applicaitons::applications
::applyed::applied
::appointiment::appointment
::appologies::apologies
::appology::apology
::apprearance::appearance
::apprieciate::appreciate
::approachs::approaches
::approch::approach
::appropiate::appropriate
::appropraite::appropriate
::appropropiate::appropriate
::approproximate::approximate
::approriate::appropriate
::approrpiate::appropriate
::approrpriate::appropriate
::approxamately::approximately
::approxiately::approximately
::approximitely::approximately
::aprehensive::apprehensive
::apropriate::appropriate
::aproximate::approximate
::aproximately::approximately
::aquaintance::acquaintance
::aquainted::acquainted
::aquiantance::acquaintance
::aquire::acquire
::aquired::acquired
::aquiring::acquiring
::aquisition::acquisition
::aquisitions::acquisitions
::aquitted::acquitted
::aranged::arranged
::arangement::arrangement
::arbitarily::arbitrarily
::arbitary::arbitrary
::archaelogists::archaeologists
::archaelogy::archaeology
::archetect::architect
::archetects::architects
::archetectural::architectural
::archetecturally::architecturally
::archetecture::architecture
::archiac::archaic
::archictect::architect
::archimedian::archimedean
::architechturally::architecturally
::architechture::architecture
::architechtures::architectures
::architectual::architectural
::archtype::archetype
::archtypes::archetypes
::aready::already
::aren;t::aren't
::areodynamics::aerodynamics
::argubly::arguably
::arguement::argument
::arguements::arguments
::arised::arose
::arival::arrival
::armamant::armament
::armistace::armistice
::arn't::aren't
::arond::around
::aroud::around
::arrangment::arrangement
::arrangments::arrangements
::arround::around
::artical::article
::artice::article
::articel::article
::artifical::artificial
::artifically::artificially
::artillary::artillery
::arund::around
::ascendency::ascendancy
::asdvertising::advertising
::asetic::ascetic
::asign::assign
::askt he::ask the
::aslo::also
::asociated::associated
::asorbed::absorbed
::asphyxation::asphyxiation
::assasin::assassin
::assasinate::assassinate
::assasinated::assassinated
::assasinates::assassinates
::assasination::assassination
::assasinations::assassinations
::assasined::assassinated
::assasins::assassins
::assassintation::assassination
::assemple::assemble
::assertation::assertion
::asside::aside
::assisnate::assassinate
::assistent::assistant
::assit::assist
::assitant::assistant
::assocation::association
::assoicate::associate
::assoicated::associated
::assoicates::associates
::assosication::assassination
::asssassans::assassins
::assualt::assault
::assualted::assaulted
::assumign::assuming
::assymetric::asymmetric
::assymetrical::asymmetrical
::asteriod::asteroid
::asthe::as the
::asthetic::aesthetic
::asthetical::aesthetical
::asthetically::aesthetically
::asume::assume
::aswell::as well
::atain::attain
::atempting::attempting
::atention::attention
::atheistical::atheistic
::athenean::athenian
::atheneans::athenians
::athiesm::atheism
::athiest::atheist
::atmospher::atmosphere
::atorney::attorney
::atribute::attribute
::atributed::attributed
::atributes::attributes
::attemp::attempt
::attemped::attempted
::attemt::attempt
::attemted::attempted
::attemting::attempting
::attemts::attempts
::attendence::attendance
::attendent::attendant
::attendents::attendants
::attened::attended
::attension::attention
::attentioin::attention
::atthe::at the
::attitide::attitude
::attributred::attributed
::attrocities::atrocities
::audeince::audience
::audiance::audience
::austrailia::australia
::austrailian::australian
::auther::author
::authobiographic::autobiographic
::authobiography::autobiography
::authorative::authoritative
::authorites::authorities
::authorithy::authority
::authoritiers::authorities
::authoritive::authoritative
::authrorities::authorities
::autochtonous::autochthonous
::autoctonous::autochthonous
::automaticly::automatically
::automibile::automobile
::automonomous::autonomous
::autor::author
::autority::authority
::auxilary::auxiliary
::auxillaries::auxiliaries
::auxillary::auxiliary
::auxilliaries::auxiliaries
::auxilliary::auxiliary
::availablility::availability
::availablity::availability
::availaible::available
::availalbe::available
::availble::available
::availiable::available
::availible::available
::avalable::available
::avalance::avalanche
::avaliable::available
::avation::aviation
::avengence::a vengeance
::averageed::averaged
::avilable::available
::awared::awarded
::awya::away
::aywa::away
::baceause::because
::backgorund::background
::backrounds::backgrounds
::bakc::back
::balence::balance
::ballance::balance
::banannas::bananas
::bandwith::bandwidth
::bankrupcy::bankruptcy
::banruptcy::bankruptcy
::baout::about
::basicaly::basically
::basicly::basically
::bcak::back
::beachead::beachhead
::beacuse::because
::beastiality::bestiality
::beatiful::beautiful
::beaurocracy::bureaucracy
::beaurocratic::bureaucratic
::beautyfull::beautiful
::becamae::became
::becasue::because
::becaus::because
::becausea::because a
::becauseof::because of
::becausethe::because the
::becauseyou::because you
::beccause::because
::becomeing::becoming
::becomming::becoming
::becouse::because
::becuase::because
::becuse::because
::bedore::before
::befoer::before
::begginer::beginner
::begginers::beginners
::beggining::beginning
::begginings::beginnings
::beggins::begins
::begining::beginning
::beginining::beginning
::beginnig::beginning
::beleagured::beleaguered
::beleiev::believe
::beleieve::believe
::beleif::belief
::beleive::believe
::beleived::believed
::beleives::believes
::beleiving::believing
::beligum::belgium
::belive::believe
::belived::believed
::belligerant::belligerent
::bemusemnt::bemusement
::beneficary::beneficiary
::beng::being
::benificial::beneficial
::benifit::benefit
::benifits::benefits
::bergamont::bergamot
::Bernouilli::Bernoulli
::beseige::besiege
::beseiged::besieged
::beseiging::besieging
::betwen::between
::beutiful::beautiful
::bewteen::between
::bilateraly::bilaterally
::billingualism::bilingualism
::binominal::binomial
::bizzare::bizarre
::blaim::blame
::blaimed::blamed
::blase::blas�
::blessure::blessing
::Blitzkreig::Blitzkrieg
::bodydbuilder::bodybuilder
::bombardement::bombardment
::bombarment::bombardment
::bondary::boundary
::Bonnano::Bonanno
::borke::broke
::boundry::boundary
::bouyancy::buoyancy
::bouyant::buoyant
::boxs::boxes
::boyant::buoyant
::Brasillian::Brazilian
::breakthough::breakthrough
::breakthroughts::breakthroughs
::breif::brief
::breifly::briefly
::brethen::brethren
::bretheren::brethren
::briliant::brilliant
::brillant::brilliant
::brimestone::brimstone
::Britian::Britain
::Brittish::British
::broacasted::broadcast
::broadacasting::broadcasting
::broady::broadly
::brodcast::broadcast
::broswer::browaser
::Buddah::Buddha
::buisness::business
::buisnessman::businessman
::buoancy::buoyancy
::burried::buried
::busness::business
::bussiness::business
::butthe::but the
::bve::be
::byt he::by the
::cacuses::caucuses
::cafe::caf�
::caharcter::character
::cahracters::characters
::calaber::caliber
::calcullated::calculated
::calculs::calculus
::calenders::calendars
::caligraphy::calligraphy
::caluclate::calculate
::caluclated::calculated
::caluculate::calculate
::caluculated::calculated
::calulate::calculate
::calulated::calculated
::Cambrige::Cambridge
::camoflage::camouflage
::campain::campaign
::campains::campaigns
::can;t::can't
::cancelled::canceled
::cancelling::canceling
::candadate::candidate
::candiate::candidate
::candidiate::candidate
::candidtae::candidate
::candidtaes::candidates
::cannister::canister
::cannisters::canisters
::cannnot::cannot
::cannonical::canonical
::cannotation::connotation
::cannotations::connotations
::can't of been::can't have been
::cantalope::cantaloupe
::caost::coast
::caperbility::capability
::Capetown::Cape Town
::capible::capable
::captial::capital
::captued::captured
::capturd::captured
::carachter::character
::caracterized::characterized
::carefull::careful
::careing::caring
::carismatic::charismatic
::Carmalite::Carmelite
::carniverous::carnivorous
::carraige::carriage
::carreer::career
::carrers::careers
::Carribbean::Caribbean
::Carribean::Caribbean
::cartdridge::cartridge
::Carthagian::Carthaginian
::carthographer::cartographer
::cartilege::cartilage
::cartilidge::cartilage
::cartrige::cartridge
::casette::cassette
::casion::caisson
::cassawory::cassowary
::cassowarry::cassowary
::casulaties::casualties
::casulaty::casualty
::catagories::categories
::catagorized::categorized
::catagory::category
::categiory::category
::cathlic::catholic
::catholocism::catholicism
::catterpilar::caterpillar
::catterpilars::caterpillars
::cattleship::battleship
::causalities::casualties
::Ceasar::Caesar
::Celcius::Celsius
::cellpading::cellpadding
::cementary::cemetery
::cemetarey::cemetery
::cemetaries::cemeteries
::cemetary::cemetery
::cencus::census
::cententenial::centennial
::centruies::centuries
::centruy::century
::cerimonial::ceremonial
::cerimonies::ceremonies
::cerimonious::ceremonious
::cerimony::ceremony
::ceromony::ceremony
::certainity::certainty
::certian::certain
::chalenging::challenging
::challange::challenge
::challanged::challenged
::challanges::challenges
::challege::challenge
::Champange::Champagne
::chaneg::change
::chanegs::changes
::changable::changeable
::changeing::changing
::changng::changing
::charachter::character
::charachters::characters
::charactersistic::characteristic
::charactor::character
::charactors::characters
::charasmatic::charismatic
::charaterized::characterized
::charecter::character
::charector::character
::chariman::chairman
::charistics::characteristics
::chartiable::charitable
::cheif::chief
::chekc::check
::chemcial::chemical
::chemcially::chemically
::chemestry::chemistry
::chemicaly::chemically
::childbird::childbirth
::childen::children
::chnage::change
::chnages::changes
::choosen::chosen
::chracter::character
::chuch::church
::churchs::churches
::cieling::ceiling
::Cincinatti::Cincinnati
::Cincinnatti::Cincinnati
::circulaton::circulation
::circumsicion::circumcision
::circut::circuit
::ciricuit::circuit
::ciriculum::curriculum
::civillian::civilian
::claer::clear
::claered::cleared
::claerer::clearer
::claerly::clearly
::claimes::claims
::clas::class
::clasic::classic
::clasical::classical
::clasically::classically
::cleareance::clearance
::cliant::client
::cliche::clich�
::clincial::clinical
::clinicaly::clinically
::cmoputer::computer
::cna::can
::coctail::cocktail
::coform::conform
::cognizent::cognizant
::coincedentally::coincidentally
::co-incided::coincided
::colaborations::collaborations
::colateral::collateral
::colection::collection
::colelctive::collective
::collaberative::collaborative
::collecton::collection
::collegue::colleague
::collegues::colleagues
::collonade::colonnade
::collonies::colonies
::collony::colony
::collosal::colossal
::colonizators::colonizers
::comando::commando
::comandos::commandos
::comanies::companies
::comany::company
::comapany::company
::comapnies::companies
::comapny::company
::comback::comeback
::combanations::combinations
::combinatins::combinations
::combintation::combination
::combusion::combustion
::comdemnation::condemnation
::comemmorates::commemorates
::comemoretion::commemoration
::comign::coming
::comision::commission
::comisioned::commissioned
::comisioner::commissioner
::comisioning::commissioning
::comisions::commissions
::comission::commission
::comissioned::commissioned
::comissioner::commissioner
::comissioning::commissioning
::comissions::commissions
::comited::committed
::comiting::committing
::comitted::committed
::comittee::committee
::comitting::committing
::commadn::command
::commandoes::commandos
::commedic::comedic
::commemerative::commemorative
::commemmorate::commemorate
::commemmorating::commemorating
::commerical::commercial
::commerically::commercially
::commericial::commercial
::commericially::commercially
::commerorative::commemorative
::comming::coming
::comminication::communication
::commision::commission
::commisioned::commissioned
::commisioner::commissioner
::commisioning::commissioning
::commisions::commissions
::commited::committed
::commitee::committee
::commiting::committing
::committe::committee
::committment::commitment
::committments::commitments
::committy::committee
::commmemorated::commemorated
::commongly::commonly
::commonweath::commonwealth
::commuications::communications
::commuinications::communications
::communciation::communication
::communiation::communication
::communites::communities
::comntain::contain
::comntains::contains
::compability::compatibility
::compair::compare
::company;s::company's
::comparision::comparison
::comparisions::comparisons
::comparitive::comparative
::comparitively::comparatively
::compatabilities::compatibilities
::compatability::compatibility
::compatable::compatible
::compatablities::compatibilities
::compatablity::compatibility
::compatiable::compatible
::compatiblities::compatibilities
::compatiblity::compatibility
::compeitions::competitions
::compensantion::compensation
::competance::competence
::competant::competent
::competative::competitive
::competitiion::competition
::competive::competitive
::competiveness::competitiveness
::comphrehensive::comprehensive
::compitent::competent
::compleated::completed
::compleatly::completely
::compleatness::completeness
::completedthe::completed the
::completelyl::completely
::completetion::completion
::completly::completely
::completness::completeness
::complier::compiler
::componant::component
::composate::composite
::comprimise::compromise
::compulsary::compulsory
::compulsery::compulsory
::computarized::computerized
::comtain::contain
::comtains::contains
::comunicate::communicate
::comunity::community
::conceintious::conscientious
::concensus::consensus
::concider::consider
::concidered::considered
::concidering::considering
::conciders::considers
::concieted::conceited
::concieved::conceived
::concious::conscious
::conciously::consciously
::conciousness::consciousness
::condamned::condemned
::condemmed::condemned
::condidtion::condition
::condidtions::conditions
::conditionsof::conditions of
::condolances::condolences
::conected::connected
::conection::connection
::conesencus::consensus
::conferance::conference
::confidental::confidential
::confidentally::confidentially
::confids::confides
::configureable::configurable
::confirmmation::confirmation
::confortable::comfortable
::congradulations::congratulations
::congresional::congressional
::conived::connived
::conjecutre::conjecture
::conjuction::conjunction
::Conneticut::Connecticut
::conotations::connotations
::conquerd::conquered
::conquerer::conqueror
::conquerers::conquerors
::conqured::conquered
::conscent::consent
::consciouness::consciousness
::consdider::consider
::consdidered::considered
::consdiered::considered
::consectutive::consecutive
::consenquently::consequently
::consentrate::concentrate
::consentrated::concentrated
::consentrates::concentrates
::consept::concept
::consequentually::consequently
::consequeseces::consequences
::consern::concern
::conserned::concerned
::conserning::concerning
::conservitive::conservative
::consiciousness::consciousness
::consicousness::consciousness
::considerd::considered
::consideres::considered
::considerit::considerate
::considerite::considerate
::consious::conscious
::consistant::consistent
::consistantly::consistently
::consituencies::constituencies
::consituency::constituency
::consituted::constituted
::consitution::constitution
::consitutional::constitutional
::consolodate::consolidate
::consolodated::consolidated
::consonent::consonant
::consonents::consonants
::consorcium::consortium
::conspiracys::conspiracies
::conspiriator::conspirator
::conspiricy::conspiracy
::constaints::constraints
::constanly::constantly
::constarnation::consternation
::constatn::constant
::constinually::continually
::constituant::constituent
::constituants::constituents
::constituion::constitution
::constituional::constitutional
::consttruction::construction
::constuction::construction
::consulant::consultant
::consultent::consultant
::consumate::consummate
::consumated::consummated
::contaiminate::contaminate
::containes::contains
::contamporaries::contemporaries
::contamporary::contemporary
::contempoary::contemporary
::contemporaneus::contemporaneous
::contempory::contemporary
::contendor::contender
::contined::continued
::continous::continuous
::continously::continuously
::continueing::continuing
::contravercial::controversial
::contraversy::controversy
::contributer::contributor
::contributers::contributors
::contritutions::contributions
::controled::controlled
::controling::controlling
::controll::control
::controlls::controls
::controvercial::controversial
::controvercy::controversy
::controveries::controversies
::controversal::controversial
::controvertial::controversial
::controvery::controversy
::contruction::construction
::conveinent::convenient
::convenant::covenant
::convential::conventional
::convertable::convertible
::convertables::convertibles
::convertion::conversion
::convertor::converter
::convertors::converters
::conveyer::conveyor
::conviced::convinced
::convienient::convenient
::cooparate::cooperate
::cooporate::cooperate
::coordiantion::coordination
::coorperations::corporations
::copmetitors::competitors
::coputer::computer
::copywrite::copyright
::coridal::cordial
::corosion::corrosion
::corparate::corporate
::corperations::corporations
::corproation::corporation
::corproations::corporations
::correcters::correctors
::correponding::corresponding
::correposding::corresponding
::correspondant::correspondent
::correspondants::correspondents
::corridoors::corridors
::corrispond::correspond
::corrispondant::correspondent
::corrispondants::correspondents
::corrisponded::corresponded
::corrisponding::corresponding
::corrisponds::corresponds
::corruptable::corruptible
::costitution::constitution
::cotten::cotton
::coucil::council
::coudl::could
::coudln't::couldn't
::coudn't::couldn't
::could of been::could have been
::could of had::could have had
::couldn;t::couldn't
::couldnt::couldn't
::couldthe::could the
::counries::countries
::countains::contains
::countires::countries
::cpoy::copy
::creaeted::created
::creedence::credence
::creme::cr�me
::critereon::criterion
::criterias::criteria
::criticists::critics
::critisising::criticising
::critisism::criticism
::critisisms::criticisms
::critized::criticized
::critizing::criticizing
::crockodiles::crocodiles
::crtical::critical
::crticised::criticised
::crucifiction::crucifixion
::crusies::cruises
::crystalisation::crystallisation
::ctaegory::category
::culiminating::culminating
::cumulatative::cumulative
::curch::church
::curcuit::circuit
::currenly::currently
::curriculem::curriculum
::cusotmer::customer
::cusotmers::customers
::cutsomer::customer
::cutsomers::customers
::cxan::can
::cxan::cyan
::cyclinder::cylinder
::dalmation::dalmatian
::damenor::demeanor
::danceing::dancing
::Dardenelles::Dardanelles
::dcument::document
::deatils::details
::debateable::debatable
::decendant::descendant
::decendants::descendants
::decendent::descendant
::decendents::descendants
::decideable::decidable
::decidely::decidedly
::decieved::deceived
::decison::decision
::decisons::decisions
::decomissioned::decommissioned
::decomposit::decompose
::decomposited::decomposed
::decompositing::decomposing
::decomposits::decomposes
::decor::d�cor
::decress::decrees
::decribe::describe
::decribed::described
::decribes::describes
::decribing::describing
::dectect::detect
::defendent::defendant
::defendents::defendants
::deffensively::defensively
::deffine::define
::deffined::defined
::definance::defiance
::definate::definite
::definately::definitely
::definatly::definitely
::definetly::definitely
::definining::defining
::definit::definite
::definitly::definitely
::definiton::definition
::defintion::definition
::degrate::degrade
::deja vu::d�j� vu
::delagates::delegates
::delapidated::dilapidated
::delerious::delirious
::delevopment::development
::deliberatly::deliberately
::delusionally::delusively
::demenor::demeanor
::demographical::demographic
::demolision::demolition
::demorcracy::democracy
::demostration::demonstration
::denegrating::denigrating
::densly::densely
::dependance::dependence
::dependancy::dependency
::dependant::dependent
::deptartment::department
::deriviated::derived
::derivitive::derivative
::derogitory::derogatory
::descendands::descendants
::descibed::described
::descision::decision
::descisions::decisions
::descriibes::describes
::descripters::descriptors
::descriptoin::description
::descripton::description
::desctruction::destruction
::descuss::discuss
::desgined::designed
::desicion::decision
::desicions::decisions
::deside::decide
::desigining::designing
::desinations::destinations
::desintegrated::disintegrated
::desintegration::disintegration
::desireable::desirable
::desision::decision
::desisions::decisions
::desitned::destined
::desktiop::desktop
::desorder::disorder
::desoriented::disoriented
::desparate::desperate
::desparately::desperately
::despatched::dispatched
::despict::depict
::despiration::desperation
::dessicated::desiccated
::dessigned::designed
::destablized::destabilized
::destory::destroy
::detailled::detailed
::detatched::detached
::detente::d�tente
::deteoriated::deteriorated
::deteriate::deteriorate
::deterioriating::deteriorating
::determinining::determining
::detremental::detrimental
::devasted::devastated
::develeoprs::developers
::devellop::develop
::develloped::developed
::develloper::developer
::devellopers::developers
::develloping::developing
::devellopment::development
::devellopments::developments
::devellops::develop
::develope::develop
::developement::development
::developements::developments
::developor::developer
::developors::developers
::developped::developed
::develpment::development
::devels::delves
::devestated::devastated
::devestating::devastating
::devide::divide
::devided::divided
::devistating::devastating
::devolopement::development
::diablical::diabolical
::diamons::diamonds
::diaplay::display
::diaster::disaster
::dichtomy::dichotomy
::diconnects::disconnects
::dicover::discover
::dicovered::discovered
::dicovering::discovering
::dicovers::discovers
::dicovery::discovery
::dicussed::discussed
::didint::didn't
::didn;t::didn't
::didnot::did not
::didnt::didn't
::dieties::deities
::diety::deity
::difefrent::different
::diferences::differences
::diferent::different
::diferrent::different
::diffcult::difficult
::diffculties::difficulties
::diffculty::difficulty
::differance::difference
::differances::differences
::differant::different
::differemt::different
::differentiatiations::differentiations
::differnt::different
::difficulity::difficulty
::difficut::difficult
::diffrent::different
::dificulties::difficulties
::dificulty::difficulty
::dimenions::dimensions
::dimention::dimension
::dimentional::dimensional
::dimentions::dimensions
::dimesnional::dimensional
::diminuitive::diminutive
::diosese::diocese
::diphtong::diphthong
::diphtongs::diphthongs
::diplomancy::diplomacy
::dipthong::diphthong
::dipthongs::diphthongs
::directer::director
::directers::directors
::directiosn::direction
::dirived::derived
::disagreeed::disagreed
::disapeared::disappeared
::disapointing::disappointing
::disappearred::disappeared
::disaproval::disapproval
::disasterous::disastrous
::disatisfaction::dissatisfaction
::disatisfied::dissatisfied
::disatrous::disastrous
::discontentment::discontent
::discoverd::discovered
::discribe::describe
::discribed::described
::discribes::describes
::discribing::describing
::disctinction::distinction
::disctinctive::distinctive
::disemination::dissemination
::disenchanged::disenchanted
::disign::design
::disiplined::disciplined
::disobediance::disobedience
::disobediant::disobedient
::disolved::dissolved
::disover::discover
::dispair::despair
::dispaly::display
::disparingly::disparagingly
::dispence::dispense
::dispenced::dispensed
::dispencing::dispensing
::dispicable::despicable
::dispite::despite
::dispostion::disposition
::disproportiate::disproportionate
::disputandem::disputandum
::disricts::districts
::dissagreement::disagreement
::dissapear::disappear
::dissapearance::disappearance
::dissapeared::disappeared
::dissapearing::disappearing
::dissapears::disappears
::dissappear::disappear
::dissappears::disappears
::dissappointed::disappointed
::dissarray::disarray
::dissobediance::disobedience
::dissobediant::disobedient
::dissobedience::disobedience
::dissobedient::disobedient
::dissonent::dissonant
::distiction::distinction
::distingish::distinguish
::distingished::distinguished
::distingishes::distinguishes
::distingishing::distinguishing
::distingquished::distinguished
::distribusion::distribution
::distrubution::distribution
::distruction::destruction
::distructive::destructive
::ditributed::distributed
::divice::device
::divison::division
::divisons::divisions
::divsion::division
::doccument::document
::doccumented::documented
::doccuments::documents
::docrines::doctrines
::doctines::doctrines
::docuement::documents
::docuemnt::document
::documenatry::documentary
::documetn::document
::documnet::document
::documnets::documents
::doe snot::does not
::doens::does
::doens't::doesn't
::doese::does
::doesn;t::doesn't
::doesnt::doesn't
::doign::doing
::doimg::doing
::doind::doing
::dollers::dollars
::dominaton::domination
::dominent::dominant
::dominiant::dominant
::don;t::don't
::donig::doing
::don't no::don't know
::dont::don't
::do'nt::don't
::dosen't::doesn't
::dosn't::doesn't
::doulbe::double
::dowloads::downloads
::dramtic::dramatic
::draughtman::draughtsman
::Dravadian::Dravidian
::dreasm::dreams
::driectly::directly
::driveing::driving
::drnik::drink
::druming::drumming
::drummless::drumless
::dukeship::dukedom
::dumbell::dumbbell
::dupicate::duplicate
::durig::during
::durring::during
::duting::during
::dyas::dryas
::eahc::each
::ealier::earlier
::earlies::earliest
::earnt::earned
::ecclectic::eclectic
::eceonomy::economy
::ecidious::deciduous
::eclair::�clair
::eclispe::eclipse
::ecomonic::economic
::ect::etc
::eearly::early
::efel::evil
::efel::feel
::effeciency::efficiency
::effecient::efficient
::effeciently::efficiently
::efficency::efficiency
::efficent::efficient
::efficently::efficiently
::effulence::effluence
::efort::effort
::eforts::efforts
::ehr::her
::eiter::either
::electrial::electrical
::electricly::electrically
::electricty::electricity
::elementay::elementary
::eleminated::eliminated
::eleminating::eliminating
::eles::eels
::eletricity::electricity
::elicided::elicited
::eligable::eligible
::elimentary::elementary
::ellected::elected
::elphant::elephant
::embarass::embarrass
::embarassed::embarrassed
::embarassing::embarrassing
::embarassment::embarrassment
::embargos::embargoes
::embarras::embarrass
::embarrased::embarrassed
::embarrasing::embarrassing
::embarrasment::embarrassment
::embezelled::embezzled
::emblamatic::emblematic
::emigre::�migr�
::eminate::emanate
::eminated::emanated
::emision::emission
::emited::emitted
::emiting::emitting
::emmediately::immediately
::emmigrated::emigrated
::emminently::eminently
::emmisaries::emissaries
::emmisarries::emissaries
::emmisarry::emissary
::emmisary::emissary
::emmision::emission
::emmisions::emissions
::emmited::emitted
::emmiting::emitting
::emmitted::emitted
::emmitting::emitting
::emnity::enmity
::emperical::empirical
::emphaised::emphasised
::emphsis::emphasis
::emphysyma::emphysema
::emprisoned::imprisoned
::enameld::enameled
::enchancement::enhancement
::encouraing::encouraging
::encryptiion::encryption
::encylopedia::encyclopedia
::endevors::endeavors
::endevour::endeavour
::endig::ending
::endolithes::endoliths
::enduce::induce
::ened::need
::enflamed::inflamed
::enforceing::enforcing
::engagment::engagement
::engeneer::engineer
::engeneering::engineering
::engieneer::engineer
::engieneers::engineers
::enlargment::enlargement
::enlargments::enlargements
::enought::enough
::enourmous::enormous
::enourmously::enormously
::ensconsed::ensconced
::entaglements::entanglements
::enteratinment::entertainment
::entitity::entity
::entitlied::entitled
::entree::entr�e
::entrepeneur::entrepreneur
::entrepeneurs::entrepreneurs
::enviorment::environment
::enviormental::environmental
::enviormentally::environmentally
::enviorments::environments
::enviornment::environment
::enviornmental::environmental
::enviornmentalist::environmentalist
::enviornmentally::environmentally
::enviornments::environments
::enviroment::environment
::enviromental::environmental
::enviromentalist::environmentalist
::enviromentally::environmentally
::enviroments::environments
::envolutionary::evolutionary
::envrionments::environments
::enxt::next
::epidsodes::episodes
::epistilary::epistolary
::epsiode::episode
::equialent::equivalent
::equilibium::equilibrium
::equilibrum::equilibrium
::equiped::equipped
::equippment::equipment
::equitorial::equatorial
::equivalant::equivalent
::equivelant::equivalent
::equivelent::equivalent
::equivilant::equivalent
::equivilent::equivalent
::equivlalent::equivalent
::eratic::erratic
::eratically::erratically
::eraticly::erratically
::errupted::erupted
::esential::essential
::esitmated::estimated
::esle::else
::especally::especially
::especialy::especially
::especialyl::especially
::espesially::especially
::essencial::essential
::essense::essence
::essentail::essential
::essentialy::essentially
::essentual::essential
::essesital::essential
::estabishes::establishes
::establising::establishing
::ethnocentricm::ethnocentrism
::euphamism::euphemism
::Europian::European
::Europians::Europeans
::Eurpean::European
::Eurpoean::European
::evenhtually::eventually
::eventally::eventually
::eventially::eventually
::eventualy::eventually
::everthing::everything
::everythign::everything
::everytime::every time
::eveyr::every
::evidentally::evidently
::exagerate::exaggerate
::exagerated::exaggerated
::exagerates::exaggerates
::exagerating::exaggerating
::exagerrate::exaggerate
::exagerrated::exaggerated
::exagerrates::exaggerates
::exagerrating::exaggerating
::examinated::examined
::exampt::exempt
::exapansion::expansion
::excact::exact
::excange::exchange
::excecute::execute
::excecuted::executed
::excecutes::executes
::excecuting::executing
::excecution::execution
::excedded::exceeded
::excelent::excellent
::excell::excel
::excellance::excellence
::excellant::excellent
::excells::excels
::excercise::exercise
::exchagne::exchange
::exchagnes::exchanges
::exchanching::exchanging
::excisted::existed
::excitment::excitement
::exculsivly::exclusively
::execising::exercising
::exection::execution
::exectued::executed
::exeedingly::exceedingly
::exelent::excellent
::exellent::excellent
::exemple::example
::exept::except
::exeptional::exceptional
::exerbate::exacerbate
::exerbated::exacerbated
::exerciese::exercises
::exerpt::excerpt
::exerpts::excerpts
::exersize::exercise
::exerternal::external
::exhalted::exalted
::exhcange::exchange
::exhcanges::exchanges
::exhibtion::exhibition
::exibition::exhibition
::exibitions::exhibitions
::exicting::exciting
::exinct::extinct
::existance::existence
::existant::existent
::existince::existence
::exliled::exiled
::exludes::excludes
::exmaple::example
::exonorate::exonerate
::exoskelaton::exoskeleton
::expalin::explain
::expeced::expected
::expecially::especially
::expeditonary::expeditionary
::expeiments::experiments
::expell::expel
::expells::expels
::experiance::experience
::experianced::experienced
::experienc::experience
::expiditions::expeditions
::expierence::experience
::explaination::explanation
::explaning::explaining
::explictly::explicitly
::exploititive::exploitative
::explotation::exploitation
::exprience::experience
::exprienced::experienced
::expropiated::expropriated
::expropiation::expropriation
::exressed::expressed
::extemely::extremely
::extention::extension
::extentions::extensions
::extered::exerted
::extermist::extremist
::extradiction::extradition
::extraterrestial::extraterrestrial
::extraterrestials::extraterrestrials
::extravagent::extravagant
::extrememly::extremely
::extremeophile::extremophile
::extremly::extremely
::extrordinarily::extraordinarily
::extrordinary::extraordinary
::eyt::yet
::facade::fa�ade
::faciliate::facilitate
::faciliated::facilitated
::faciliates::facilitates
::facilites::facilities
::facillitate::facilitate
::facinated::fascinated
::facist::fascist
::faeture::feature
::faetures::features
::familair::familiar
::familar::familiar
::familes::families
::familliar::familiar
::fammiliar::familiar
::famoust::famous
::fanatism::fanaticism
::Farenheit::Fahrenheit
::fascitis::fasciitis
::faught::fought
::favoutrable::favourable
::feasable::feasible
::Febuary::February
::fedreally::federally
::feild::field
::feilds::fields
::feromone::pheromone
::fertily::fertility
::fianite::finite
::fianlly::finally
::ficticious::fictitious
::fictious::fictitious
::fidn::find
::fiercly::fiercely
::fightings::fighting
::filiament::filament
::fimilies::families
::finacial::financial
::finaly::finally
::finalyl::finally
::financialy::financially
::firends::friends
::firts::first
::fisionable::fissionable
::flamable::flammable
::flawess::flawless
::Flemmish::Flemish
::flexibile::flexible
::florescent::fluorescent
::flourescent::fluorescent
::fluorish::flourish
::focussed::focused
::focusses::focuses
::focussing::focusing
::follwo::follow
::follwoing::following
::folowing::following
::fomed::formed
::fonetic::phonetic
::fontrier::fontier
::foootball::football
::fora::for a
::forbad::forbade
::forbiden::forbidden
::foreigh::foreign
::foreward::foreword
::forfiet::forfeit
::forgiveable::forgivable
::forhead::forehead
::foriegn::foreign
::Formalhaut::Fomalhaut
::formallize::formalize
::formallized::formalized
::formaly::formally
::formelly::formerly
::formost::foremost
::forsaw::foresaw
::forseeable::foreseeable
::fortelling::foretelling
::forthe::for the
::forunner::forerunner
::forwrd::forward
::forwrds::forwards
::foucs::focus
::foudn::found
::fougth::fought
::foundaries::foundries
::foundary::foundry
::Foundland::Newfoundland
::fourties::forties
::fourty::forty
::fouth::fourth
::foward::forward
::fowards::forwards
::Fransiscan::Franciscan
::Fransiscans::Franciscans
::freind::friend
::freindly::friendly
::freinds::friends
::frequentily::frequently
::frmo::from
::fro::for
::frome::from
::fromed::formed
::fromt he::from the
::fromthe::from the
::froniter::frontier
::fufill::fulfill
::fufilled::fulfilled
::fulfiled::fulfilled
::fundametal::fundamental
::fundametals::fundamentals
::funguses::fungi
::funtion::function
::furneral::funeral
::furuther::further
::futher::further
::futhermore::furthermore
::fwe::few
::galatic::galactic
::Galations::Galatians
::gallaxies::galaxies
::galvinized::galvanized
::Gameboy::Game Boy
::ganes::games
::ganster::gangster
::garantee::guarantee
::garanteed::guaranteed
::garantees::guarantees
::garnison::garrison
::gauarana::guarana
::gaurantee::guarantee
::gauranteed::guaranteed
::gaurantees::guarantees
::gaurd::guard
::gaurentee::guarantee
::gaurenteed::guaranteed
::gaurentees::guarantees
::gemeral::general
::geneological::genealogical
::geneologies::genealogies
::geneology::genealogy
::generaly::generally
::generatting::generating
::genialia::genitalia
::geographicial::geographical
::geometrician::geometer
::geometricians::geometers
::gerat::great
::geting::getting
::gettin::getting
::Ghandi::Gandhi
::gievn::given
::giveing::giving
::glace::glance
::glight::flight
::gloabl::global
::gnawwed::gnawed
::godess::goddess
::godesses::goddesses
::Godounov::Godunov
::goign::going
::gonig::going
::Gothenberg::Gothenburg
::Gottleib::Gottlieb
::gouvener::governor
::govement::government
::govenment::government
::govenrment::government
::goverance::governance
::goverment::government
::govermental::governmental
::governer::governor
::governmnet::government
::govorment::government
::govormental::governmental
::govornment::government
::gracefull::graceful
::graet::great
::grafitti::graffiti
::gramatically::grammatically
::grammaticaly::grammatically
::grammer::grammar
::grat::great
::gratuitious::gratuitous
::greatful::grateful
::greatfully::gratefully
::greif::grief
::gridles::griddles
::gropu::group
::gruop::group
::gruops::groups
::grwo::grow
::guage::gauge
::guarentee::guarantee
::guarenteed::guaranteed
::guarentees::guarantees
::Guatamala::Guatemala
::Guatamalan::Guatemalan
::guidence::guidance
::guidlines::guidelines
::Guilia::Giulia
::Guilio::Giulio
::Guiness::Guinness
::Guiseppe::Giuseppe
::gunanine::guanine
::gurantee::guarantee
::guranteed::guaranteed
::gurantees::guarantees
::gusy::guys
::guttaral::guttural
::gutteral::guttural
::habaeus::habeas
::habeus::habeas
::Habsbourg::Habsburg
::hadbeen::had been
::hadn;t::hadn't
::haemorrage::haemorrhage
::haev::have
::halp::help
::hapen::happen
::hapened::happened
::hapening::happening
::hapens::happens
::happend::happened
::happended::happened
::happenned::happened
::harased::harassed
::harases::harasses
::harasment::harassment
::harasments::harassments
::harassement::harassment
::harras::harass
::harrased::harassed
::harrases::harasses
::harrasing::harassing
::harrasment::harassment
::harrasments::harassments
::harrassed::harassed
::harrasses::harassed
::harrassing::harassing
::harrassment::harassment
::harrassments::harassments
::hasbeen::has been
::hasn;t::hasn't
::hasnt::hasn't
::havebeen::have been
::haveing::having
::haven;t::haven't
::haviest::heaviest
::hda::had
::he;ll::he'll
::headquater::headquarter
::headquatered::headquartered
::headquaters::headquarters
::healthercare::healthcare
::heared::heard
::hearign::hearing
::heathy::healthy
::Heidelburg::Heidelberg
::heigher::higher
::heirarchical::hierarchical
::heirarchies::hierarchies
::heirarchy::hierarchy
::heiroglyphics::hieroglyphics
::helment::helmet
::helpfull::helpful
::helpped::helped
::hemmorhage::hemorrhage
::herat::heart
::here;s::here's
::heridity::heredity
::heroe::hero
::heros::heroes
::hertzs::hertz
::hesaid::he said
::hesistant::hesitant
::heterogenous::heterogeneous
::hewas::he was
::hge::he
::hieght::height
::hierachical::hierarchical
::hierachies::hierarchies
::hierachy::hierarchy
::hierarcical::hierarchical
::hierarcy::hierarchy
::hieroglph::hieroglyph
::hieroglphs::hieroglyphs
::higer::higher
::higest::highest
::higway::highway
::hillarious::hilarious
::himselv::himself
::hinderance::hindrance
::hinderence::hindrance
::hindrence::hindrance
::hipopotamus::hippopotamus
::hismelf::himself
::histocompatability::histocompatibility
::historicians::historians
::hitsingles::hit singles
::hlep::help
::holliday::holiday
::homestate::home state
::homogeneize::homogenize
::homogeneized::homogenized
::honory::honorary
::horrifing::horrifying
::hors devours::hors d'oeuvres
::hosited::hoisted
::hospitible::hospitable
::hounour::honour
::howver::however
::hsa::has
::hsi::his
::hsitorians::historians
::hstory::history
::hte::the
::htem::them
::htere::there
::htese::these
::htey::they
::htikn::think
::hting::thing
::htink::think
::htis::this
::htp:::http:
::http:\\::http://
::httpL::http:
::huminoid::humanoid
::humoural::humoral
::humurous::humourous
::husban::husband
::hvae::have
::hvaing::having
::hwich::which
::hwihc::which
::hwile::while
::hwole::whole
::hydogen::hydrogen
::hydropile::hydrophile
::hydropilic::hydrophilic
::hydropobe::hydrophobe
::hydropobic::hydrophobic
::hygeine::hygiene
::hypocracy::hypocrisy
::hypocrasy::hypocrisy
::hypocricy::hypocrisy
::hypocrit::hypocrite
::hypocrits::hypocrites
::i snot::is not
::I"m::I'm
::i::I  ;commented out b/c it automatically capitalizes all instances of i
::I;d::I'd
::I;ll::I'll
::iconclastic::iconoclastic
::idae::idea
::idaeidae::idea
::idaes::ideas
::idealogies::ideologies
::idealogy::ideology
::identicial::identical
::identifers::identifiers
::identofy::identify
::ideosyncratic::idiosyncratic
::idiosyncracy::idiosyncrasy
::Ihaca::Ithaca
::ihs::his
::iits the::it's the
::illegimacy::illegitimacy
::illegitmate::illegitimate
::illess::illness
::illiegal::illegal
::illution::illusion
::ilness::illness
::ilogical::illogical
::imagenary::imaginary
::imagin::imagine
::imagineable::imaginable
::imcomplete::incomplete
::imediate::immediate
::imediately::immediately
::imediatly::immediately
::imense::immense
::immediatley::immediately
::immediatly::immediately
::immidately::immediately
::immidiately::immediately
::immitate::imitate
::immitated::imitated
::immitating::imitating
::immitator::imitator
::immunosupressant::immunosuppressant
::impecabbly::impeccably
::impedence::impedance
::implamenting::implementing
::impliment::implement
::implimented::implemented
::imploys::employs
::importamt::important
::importent::important
::importnat::important
::impossable::impossible
::imprioned::imprisoned
::imprisonned::imprisoned
::improvemnt::improvement
::improvision::improvisation
::improvment::improvement
::improvments::improvements
::inablility::inability
::inaccessable::inaccessible
::inadiquate::inadequate
::inadquate::inadequate
::inadvertant::inadvertent
::inadvertantly::inadvertently
::inagurated::inaugurated
::inaguration::inauguration
::inappropiate::inappropriate
::inaugures::inaugurates
::inbalance::imbalance
::inbalanced::imbalanced
::inbetween::between
::incarcirated::incarcerated
::incidentially::incidentally
::incidently::incidentally
::inclreased::increased
::includ::include
::includng::including
::incompatabilities::incompatibilities
::incompatability::incompatibility
::incompatable::incompatible
::incompatablities::incompatibilities
::incompatablity::incompatibility
::incompatiblities::incompatibilities
::incompatiblity::incompatibility
::incompetance::incompetence
::incompetant::incompetent
::incomptable::incompatible
::incomptetent::incompetent
::inconsistant::inconsistent
::incorperation::incorporation
::incorportaed::incorporated
::incorprates::incorporates
::incorruptable::incorruptible
::incramentally::incrementally
::increadible::incredible
::incredable::incredible
::inctroduce::introduce
::inctroduced::introduced
::incuding::including
::incunabla::incunabula
::indecate::indicate
::indefinately::indefinitely
::indefineable::undefinable
::indefinitly::indefinitely
::indenpendence::independence
::indenpendent::independent
::indepedantly::independently
::indepedence::independence
::indepedent::independent
::independance::independence
::independant::independent
::independantly::independently
::independece::independence
::independendet::independent
::indictement::indictment
::indigineous::indigenous
::indipendence::independence
::indipendent::independent
::indipendently::independently
::indispensible::indispensable
::indisputible::indisputable
::indisputibly::indisputably
::indite::indict
::individualy::individually
::indpendent::independent
::indpendently::independently
::indulgue::indulge
::indutrial::industrial
::indviduals::individuals
::inefficienty::inefficiently
::inevatible::inevitable
::inevitible::inevitable
::inevititably::inevitably
::infalability::infallibility
::infallable::infallible
::infectuous::infectious
::infered::inferred
::infilitrate::infiltrate
::infilitrated::infiltrated
::infilitration::infiltration
::infinit::infinite
::inflamation::inflammation
::influance::influence
::influencial::influential
::influented::influenced
::infomation::information
::informatoin::information
::informtion::information
::infrantryman::infantryman
::infrigement::infringement
::ingenius::ingenious
::ingreediants::ingredients
::inhabitans::inhabitants
::inherantly::inherently
::inheritence::inheritance
::inital::initial
::initally::initially
::initation::initiation
::initiaitive::initiative
::inlcuding::including
::inmigrant::immigrant
::inmigrants::immigrants
::innoculated::inoculated
::inocence::innocence
::inofficial::unofficial
::inot::into
::inpeach::impeach
::inpolite::impolite
::inprisonment::imprisonment
::inproving::improving
::insectiverous::insectivorous
::insensative::insensitive
::inseperable::inseparable
::insistance::insistence
::insitution::institution
::insitutions::institutions
::instade::instead
::instaleld::installed
::instatance::instance
::insted::instead
::institue::institute
::instuction::instruction
::instuments::instruments
::instutionalized::institutionalized
::instutions::intuitions
::insurence::insurance
::int he::in the
::inteh::in the
::intelectual::intellectual
::inteligence::intelligence
::inteligent::intelligent
::intenational::international
::intepretation::interpretation
::intepretator::interpretor
::interational::international
::interchangable::interchangeable
::interchangably::interchangeably
::intercontinetal::intercontinental
::interelated::interrelated
::interferance::interference
::interfereing::interfering
::intergrated::integrated
::intergration::integration
::interm::interim
::intermittant::intermittent
::internation::international
::interpet::interpret
::interrim::interim
::interrugum::interregnum
::intertaining::entertaining
::interum::interim
::interupt::interrupt
::intervines::intervenes
::intevene::intervene
::inthe::in the
::intial::initial
::intially::initially
::intrduced::introduced
::intrest::interest
::introdued::introduced
::intruduced::introduced
::intrusted::entrusted
::intutive::intuitive
::intutively::intuitively
::inudstry::industry
::inventer::inventor
::invertibrates::invertebrates
::investingate::investigate
::involvment::involvement
::inwhich::in which
::irelevent::irrelevant
::iresistable::irresistible
::iresistably::irresistibly
::iresistible::irresistible
::iresistibly::irresistibly
::iritable::irritable
::iritated::irritated
::ironicly::ironically
::irregardless::regardless
::irrelevent::irrelevant
::irreplacable::irreplaceable
::irresistable::irresistible
::irresistably::irresistibly
::isn;t::isn't
::isnt::isn't
::Israelies::Israelis
::issueing::issuing
::isthe::is the
::it snot::it's not
::it' snot::it's not
::it;ll::it'll
::it;s::it's
::itis::it is
::ititial::initial
::itnerest::interest
::itnerested::interested
::itneresting::interesting
::itnerests::interests
::itnroduced::introduced
::its a::it's a
::its the::it's the
::itwas::it was
::iunior::junior
::iwll::will
::iwth::with
::Japanes::Japanese
::jaques::jacques
::jeapardy::jeopardy
::jewllery::jewellery
::Jium::Jim
::Johanine::Johannine
::Jospeh::Joseph
::jouney::journey
::journied::journeyed
::journies::journeys
::jstu::just
::jsut::just
::Juadaism::Judaism
::Juadism::Judaism
::judgement::judgment
::judical::judicial
::judisuary::judiciary
::juducial::judicial
::jugment::judgment
::juristiction::jurisdiction
::juristictions::jurisdictions
::kindergarden::kindergarten
::klenex::kleenex
::knifes::knives
::knive::knife
::knowldge::knowledge
::knowlege::knowledge
::knowlegeable::knowledgeable
::knwo::know
::knwon::known
::knwos::knows
::konw::know
::konwn::known
::konws::knows
::kwno::know
::labelled::labeled
::lable::label
::labratory::laboratory
::laguage::language
::laguages::languages
::larg::large
::largst::largest
::larrry::larry
::lastr::last
::lastyear::last year
::lattitude::latitude
::laugher::laughter
::launchs::launch
::launhed::launched
::lavae::larvae
::layed::laid
::lazyness::laziness
::leaded::led
::leage::league
::learnign::learning
::leathal::lethal
::lefted::left
::legitamate::legitimate
::legitmate::legitimate
::leibnitz::leibniz
::lenght::length
::leran::learn
::lerans::learns
::let;s::let's
::let's him::lets him
::let's it::lets it
::leutenant::lieutenant
::levetate::levitate
::levetated::levitated
::levetates::levitates
::levetating::levitating
::levle::level
::liasion::liaison
::liason::liaison
::liasons::liaisons
::libary::library
::libell::libel
::libguistic::linguistic
::libguistics::linguistics
::libitarianisn::libertarianism
::librarry::library
::librery::library
::licence::license
::lieing::lying
::liek::like
::liekd::liked
::liesure::leisure
::lieutenent::lieutenant
::liev::live
::lieved::lived
::liftime::lifetime
::lightyear::light year
::lightyears::light years
::likelyhood::likelihood
::likly::likely
::linnaena::linnaean
::lippizaner::lipizzaner
::liquify::liquefy
::lisense::license
::listners::listeners
::litature::literature
::literture::literature
::littel::little
::litterally::literally
::litttle::little
::liuke::like
::liveing::living
::livley::lively
::lmits::limits
::loev::love
::lonelyness::loneliness
::longitudonal::longitudinal
::lonley::lonely
::lonly::lonely
::lookign::looking
::loosing::losing
::lotharingen::lothringen
::lsat::last
::lukid::likud
::lveo::love
::lvoe::love
::Lybia::Libya
::mabye::maybe
::mackeral::mackerel
::magasine::magazine
::magincian::magician
::magnificient::magnificent
::magolia::magnolia
::mailny::mainly
::maintainance::maintenance
::maintainence::maintenance
::maintance::maintenance
::maintenence::maintenance
::maintinaing::maintaining
::maintioned::mentioned
::majoroty::majority
::makeing::making
::makse::makes
::Malcom::Malcolm
::maltesian::Maltese
::mamal::mammal
::mamalian::mammalian
::managment::management
::manifestion::manifestation
::manisfestations::manifestations
::manoeuverability::maneuverability
::mantain::maintain
::mantained::maintained
::manufacturedd::manufactured
::manufature::manufacture
::manufatured::manufactured
::manufaturing::manufacturing
::manuver::maneuver
::mariage::marriage
::marjority::majority
::markes::marks
::marketting::marketing
::marmelade::marmalade
::marrage::marriage
::marraige::marriage
::marrtyred::martyred
::marryied::married
::Massachussets::Massachusetts
::Massachussetts::Massachusetts
::massmedia::mass media
::masterbation::masturbation
::mataphysical::metaphysical
::materalists::materialist
::mathamatics::mathematics
::mathematican::mathematician
::mathematicas::mathematics
::matheticians::mathematicians
::mathmatically::mathematically
::mathmatician::mathematician
::mathmaticians::mathematicians
::may of been::may have been
::may of had::may have had
::mccarthyst::mccarthyist
::mchanics::mechanics
::meaninng::meaning
::mechandise::merchandise
::medacine::medicine
::medeival::medieval
::medevial::medieval
::mediciney::mediciny
::medievel::medieval
::mediterainnean::mediterranean
::Mediteranean::Mediterranean
::meerkrat::meerkat
::melieux::milieux
::membranaphone::membranophone
::memeber::member
::menally::mentally
::mercentile::mercantile
::merchent::merchant
::mesage::message
::mesages::messages
::messanger::messenger
::messenging::messaging
::metalic::metallic
::metalurgic::metallurgic
::metalurgical::metallurgical
::metalurgy::metallurgy
::metamorphysis::metamorphosis
::metaphoricial::metaphorical
::meterologist::meteorologist
::meterology::meteorology
::methaphor::metaphor
::methaphors::metaphors
::Michagan::Michigan
::micoscopy::microscopy
::midwifes::midwives
::might of been::might have been
::might of had::might have had
::mileau::milieu
::milennia::millennia
::milennium::millennium
::mileu::milieu
::miliary::military
::milion::million
::miliraty::military
::millenia::millennia
::millenial::millennial
::millenialism::millennialism
::millenium::millennium
::millepede::millipede
::millioniare::millionaire
::millitary::military
::millon::million
::miltary::military
::minature::miniature
::minerial::mineral
::miniscule::minuscule
::ministery::ministry
::minstries::ministries
::minstry::ministry
::minumum::minimum
::mirrorred::mirrored
::miscelaneous::miscellaneous
::miscellanious::miscellaneous
::miscellanous::miscellaneous
::mischeivous::mischievous
::mischevious::mischievous
::mischievious::mischievous
::misdameanor::misdemeanor
::misdameanors::misdemeanors
::misdemenor::misdemeanor
::misdemenors::misdemeanors
::misfourtunes::misfortunes
::misile::missile
::Misouri::Missouri
::mispell::misspell
::mispelled::misspelled
::mispelling::misspelling
::mispellings::misspellings
::missen::mizzen
::Missisipi::Mississippi
::Missisippi::Mississippi
::missle::missile
::missonary::missionary
::misterious::mysterious
::mistery::mystery
::misteryous::mysterious
::mkae::make
::mkaes::makes
::mkaing::making
::mkea::make
::moderm::modem
::modle::model
::moent::moment
::moeny::money
::mohammedans::muslims
::moil::mohel
::moleclues::molecules
::monestaries::monasteries
::monickers::monikers
::monolite::monolithic
::Monserrat::Montserrat
::montains::mountains
::montanous::mountainous
::monts::months
::montypic::monotypic
::morgage::mortgage
::Morisette::Morissette
::Morrisette::Morissette
::morroccan::moroccan
::morrocco::morocco
::morroco::morocco
::mosture::moisture
::motiviated::motivated
::mottos::mottoes
::mounth::month
::movei::movie
::movment::movement
::mroe::more
::mucuous::mucous
::muder::murder
::mudering::murdering
::muhammadan::muslim
::multicultralism::multiculturalism
::multipled::multiplied
::multiplers::multipliers
::munbers::numbers
::muncipalities::municipalities
::muncipality::municipality
::munnicipality::municipality
::muscial::musical
::muscician::musician
::muscicians::musicians
::must of been::must have been
::must of had::must have had
::mutiliated::mutilated
::myraid::myriad
::mysef::myself
::mysefl::myself
::mysogynist::misogynist
::mysogyny::misogyny
::mysterous::mysterious
::Mythraic::Mithraic
::myu::my
::naieve::naive
::naive::na�ve
::Napoleonian::Napoleonic
::naturaly::naturally
::naturely::naturally
::naturual::natural
::naturually::naturally
::nauseus::nauseous
::Nazereth::Nazareth
::necassarily::necessarily
::necassary::necessary
::neccesarily::necessarily
::neccesary::necessary
::neccessarily::necessarily
::neccessary::necessary
::neccessities::necessities
::necesarily::necessarily
::necesary::necessary
::necessiate::necessitate
::neglible::negligible
::negligable::negligible
::negociable::negotiable
::negociate::negotiate
::negociation::negotiation
::negociations::negotiations
::negociator::negotiator
::negotation::negotiation
::negotiaing::negotiating
::neigborhood::neighborhood
::neigbourhood::neighbourhood
::neolitic::neolithic
::nessasarily::necessarily
::nessecary::necessary
::nestin::nesting
::neverthless::nevertheless
::newletters::newsletters
::Newyorker::New Yorker
::nickle::nickel
::nightime::nighttime
::nineth::ninth
::ninteenth::nineteenth
::ninties::1990s
::ninty::ninety
::nkow::know
::nkwo::know
::nmae::name
::noncombatents::noncombatants
::nonsence::nonsense
::nontheless::nonetheless
::noone::no one
::norhern::northern
::northen::northern
::northereastern::northeastern
::notabley::notably
::noteable::notable
::noteably::notably
::noteriety::notoriety
::noth::north
::nothern::northern
::nothign::nothing
::noticable::noticeable
::noticably::noticeably
::noticeing::noticing
::noticible::noticeable
::notwhithstanding::notwithstanding
::noveau::nouveau
::nowdays::nowadays
::nowe::now
::nto::not
::nucular::nuclear
::nuculear::nuclear
::nuisanse::nuisance
::Nullabour::Nullarbor
::numberous::numerous
::Nuremburg::Nuremberg
::nusance::nuisance
::nutritent::nutrient
::nutritents::nutrients
::nuturing::nurturing
::nver::never
::nwe::new
::nwo::now
::obediance::obedience
::obediant::obedient
::obession::obsession
::obssessed::obsessed
::obstacal::obstacle
::obstancles::obstacles
::obstruced::obstructed
::ocasion::occasion
::ocasional::occasional
::ocasionally::occasionally
::ocasionaly::occasionally
::ocasioned::occasioned
::ocasions::occasions
::ocassion::occasion
::ocassional::occasional
::ocassionally::occasionally
::ocassionaly::occasionally
::ocassioned::occasioned
::ocassions::occasions
::occaison::occasion
::occassion::occasion
::occassional::occasional
::occassionally::occasionally
::occassionaly::occasionally
::occassioned::occasioned
::occassions::occasions
::occationally::occasionally
::occour::occur
::occurance::occurrence
::occurances::occurrences
::occured::occurred
::occurence::occurrence
::occurences::occurrences
::occuring::occurring
::occurr::occur
::occurrance::occurrence
::occurrances::occurrences
::octohedra::octahedra
::octohedral::octahedral
::octohedron::octahedron
::ocuntries::countries
::ocuntry::country
::ocur::occur
::ocurr::occur
::ocurrance::occurrence
::ocurred::occurred
::ocurrence::occurrence
::oeprator::operator
::offcers::officers
::offcially::officially
::offereings::offerings
::offical::official
::offically::officially
::officaly::officially
::officialy::officially
::ofits::of its
::oft he::of the
::oftenly::often
::ofthe::of the
::oging::going
::ohter::other
::omision::omission
::omited::omitted
::omiting::omitting
::omlette::omelette
::ommision::omission
::ommited::omitted
::ommiting::omitting
::ommitted::omitted
::ommitting::omitting
::omniverous::omnivorous
::omniverously::omnivorously
::omre::more
::oneof::one of
::onepoint::one point
::ont he::on the
::onthe::on the
::onyl::only
::openess::openness
::oponent::opponent
::oportunity::opportunity
::opose::oppose
::oposite::opposite
::oposition::opposition
::oppasite::opposite
::oppenly::openly
::opperation::operation
::oppertunity::opportunity
::oppinion::opinion
::opponant::opponent
::oppononent::opponent
::opposate::opposite
::opposible::opposable
::opposit::opposite
::oppositition::opposition
::oppossed::opposed
::oppotunities::opportunities
::oppotunity::opportunity
::opprotunity::opportunity
::opression::oppression
::opressive::oppressive
::opthalmic::ophthalmic
::opthalmologist::ophthalmologist
::opthalmology::ophthalmology
::opthamologist::ophthalmologist
::optmizations::optimizations
::optomism::optimism
::orded::ordered
::organim::organism
::organiztion::organization
::orginal::original
::orginally::originally
::orginization::organization
::orginize::organise
::orginized::organized
::oridinarily::ordinarily
::origanaly::originally
::originall::originally
::originaly::originally
::originially::originally
::originnally::originally
::origional::original
::orignally::originally
::orignially::originally
::orthagonal::orthogonal
::otehr::other
::otherw::others
::otu::out
::ouevre::oeuvre
::outof::out of
::overshaddowed::overshadowed
::overthe::over the
::overthere::over there
::overwelming::overwhelming
::overwheliming::overwhelming
::owrk::work
::owudl::would
::owuld::would
::oxident::oxidant
::oxigen::oxygen
::oximoron::oxymoron
::paide::paid
::paitience::patience
::paleolitic::paleolithic
::paliamentarian::parliamentarian
::Palistian::Palestinian
::Palistinian::Palestinian
::Palistinians::Palestinians
::pallete::palette
::pamflet::pamphlet
::pamplet::pamphlet
::pantomine::pantomime
::papaer::paper
::Papanicalou::Papanicolaou
::paralel::parallel
::paralell::parallel
::paralelly::parallelly
::paralely::parallelly
::parallely::parallelly
::paranthesis::parenthesis
::paraphenalia::paraphernalia
::parellels::parallels
::parituclar::particular
::parliment::parliament
::parrakeets::parakeets
::parralel::parallel
::parrallel::parallel
::parrallell::parallel
::parrallelly::parallelly
::parrallely::parallelly
::partialy::partially
::particualr::particular
::particuarly::particularly
::particularily::particularly
::particulary::particularly
::partof::part of
::pary::party
::pased::passed
::pasengers::passengers
::passerbys::passersby
::pasttime::pastime
::pastural::pastoral
::paticular::particular
::pattented::patented
::pavillion::pavilion
::payed::paid
::paymetn::payment
::paymetns::payments
::pciture::picture
::peacefuland::peaceful and
::peageant::pageant
::peculure::peculiar
::pedestrain::pedestrian
::peice::piece
::peices::pieces
::Peloponnes::Peloponnesus
::penatly::penalty
::penerator::penetrator
::penisula::peninsula
::penisular::peninsular
::penninsula::peninsula
::penninsular::peninsular
::pennisula::peninsula
::pensinula::peninsula
::peolpe::people
::peom::poem
::peoms::poems
::peopel::people
::peotry::poetry
::perade::parade
::percentof::percent of
::percentto::percent to
::percepted::perceived
::percieve::perceive
::percieved::perceived
::perenially::perennially
::perfomers::performers
::performence::performance
::perhasp::perhaps
::perheaps::perhaps
::perhpas::perhaps
::peripathetic::peripatetic
::peristent::persistent
::perjery::perjury
::perjorative::pejorative
::permanant::permanent
::permenant::permanent
::permenantly::permanently
::perminent::permanent
::permissable::permissible
::perogative::prerogative
::peronal::personal
::perosnality::personality
::perphas::perhaps
::perpindicular::perpendicular
::perseverence::perseverance
::persistance::persistence
::persistant::persistent
::personalyl::personally
::personell::personnel
::personnell::personnel
::persuded::persuaded
::persue::pursue
::persued::pursued
::persuing::pursuing
::persuit::pursuit
::persuits::pursuits
::pertubation::perturbation
::pertubations::perturbations
::pessiary::pessary
::petetion::petition
::Pharoah::Pharaoh
::phenomenom::phenomenon
::phenomenonal::phenomenal
::phenomenonly::phenomenally
::phenomonenon::phenomenon
::phenomonon::phenomenon
::phenonmena::phenomena
::Philipines::Philippines
::philisopher::philosopher
::philisophical::philosophical
::philisophy::philosophy
::Phillipine::Philippine
::Phillipines::Philippines
::Phillippines::Philippines
::phillosophically::philosophically
::philospher::philosopher
::philosphies::philosophies
::philosphy::philosophy
::Phonecian::Phoenecian
::phongraph::phonograph
::phylosophical::philosophical
::physicaly::physically
::pich::pitch
::pilgrimmage::pilgrimage
::pilgrimmages::pilgrimages
::pinapple::pineapple
::pinnaple::pineapple
::pinoneered::pioneered
::plagarism::plagiarism
::planation::plantation
::planed::planned
::plantiff::plaintiff
::plateu::plateau
::plausable::plausible
::playright::playwright
::playwrite::playwright
::playwrites::playwrights
::pleasent::pleasant
::plebicite::plebiscite
::plesant::pleasant
::poeoples::peoples
::poeple::people
::poety::poetry
::poisin::poison
::polical::political
::polinator::pollinator
::polinators::pollinators
::politican::politician
::politicans::politicians
::poltical::political
::polute::pollute
::poluted::polluted
::polutes::pollutes
::poluting::polluting
::polution::pollution
::polyphonyic::polyphonic
::polysaccaride::polysaccharide
::polysaccharid::polysaccharide
::pomegranite::pomegranate
::pomotion::promotion
::poportional::proportional
::popoulation::population
::popularaty::popularity
::populare::popular
::porblem::problem
::porblems::problems
::portayed::portrayed
::portraing::portraying
::Portugese::Portuguese
::portuguease::portuguese
::porvide::provide
::posess::possess
::posessed::possessed
::posesses::possesses
::posessing::possessing
::posession::possession
::posessions::possessions
::posion::poison
::possable::possible
::possably::possibly
::posseses::possesses
::possesing::possessing
::possesion::possession
::possessess::possesses
::possibile::possible
::possibilty::possibility
::possibily::possibly
::possiblility::possibility
::possiblilty::possibility
::possiblities::possibilities
::possiblity::possibility
::possition::position
::Postdam::Potsdam
::posthomous::posthumous
::postion::position
::postition::position
::postive::positive
::potatos::potatoes
::potentialy::potentially
::potrayed::portrayed
::poulations::populations
::poverful::powerful
::poweful::powerful
::powerfull::powerful
::practial::practical
::practially::practically
::practicaly::practically
::practicioner::practitioner
::practicioners::practitioners
::practicly::practically
::practioner::practitioner
::practioners::practitioners
::prairy::prairie
::prarie::prairie
::praries::prairies
::pratice::practice
::preample::preamble
::precedessor::predecessor
::preceed::precede
::preceeded::preceded
::preceeding::preceding
::preceeds::precedes
::precentage::percentage
::precice::precise
::precisly::precisely
::precurser::precursor
::predecesors::predecessors
::predicatble::predictable
::predicitons::predictions
::predomiantly::predominately
::prefered::preferred
::prefering::preferring
::prefernece::preference
::preferneces::preferences
::preferrably::preferably
::pregancies::pregnancies
::pregnent::pregnant
::preiod::period
::preliferation::proliferation
::premeire::premiere
::premeired::premiered
::premillenial::premillennial
::preminence::preeminence
::premission::permission
::Premonasterians::Premonstratensians
::preocupation::preoccupation
::prepair::prepare
::prepartion::preparation
::prepatory::preparatory
::preperation::preparation
::preperations::preparations
::preriod::period
::presance::presence
::presedential::presidential
::presense::presence
::presidenital::presidential
::presidental::presidential
::presitgious::prestigious
::prespective::perspective
::prestigeous::prestigious
::prestigous::prestigious
::presumabely::presumably
::presumibly::presumably
::pretection::protection
::prevelant::prevalent
::preverse::perverse
::previvous::previous
::pricipal::principal
::priciple::principle
::priestood::priesthood
::primarly::primarily
::primative::primitive
::primatively::primitively
::primatives::primitives
::primordal::primordial
::priveledges::privileges
::privelege::privilege
::priveleged::privileged
::priveleges::privileges
::privelige::privilege
::priveliged::privileged
::priveliges::privileges
::privelleges::privileges
::privilage::privilege
::priviledge::privilege
::priviledges::privileges
::privledge::privilege
::privte::private
::probabilaty::probability
::probablistic::probabilistic
::probablly::probably
::probalby::probably
::probalibity::probability
::probaly::probably
::probelm::problem
::probelms::problems
::proccess::process
::proccessing::processing
::procedger::procedure
::procedings::proceedings
::proceedure::procedure
::proces::process
::processer::processor
::proclaimation::proclamation
::proclamed::proclaimed
::proclaming::proclaiming
::proclomation::proclamation
::profesor::professor
::professer::professor
::proffesed::professed
::proffesion::profession
::proffesional::professional
::proffesor::professor
::profilic::prolific
::progessed::progressed
::programable::programmable
::prohabition::prohibition
::projecter::projector
::prologomena::prolegomena
::prominance::prominence
::prominant::prominent
::prominantly::prominently
::promiscous::promiscuous
::promotted::promoted
::pronomial::pronominal
::pronouced::pronounced
::pronounched::pronounced
::pronounciation::pronunciation
::proove::prove
::prooved::proved
::prophacy::prophecy
::propietary::proprietary
::propmted::prompted
::propoganda::propaganda
::propogate::propagate
::propogates::propagates
::propogation::propagation
::propostion::proposition
::propotions::proportions
::propper::proper
::propperly::properly
::proprietory::proprietary
::proseletyzing::proselytizing
::protaganist::protagonist
::protaganists::protagonists
::protege::prot�g�
::protocal::protocol
::protoganist::protagonist
::protoge::prot�g�
::protrayed::portrayed
::protruberance::protuberance
::protruberances::protuberances
::prouncements::pronouncements
::provacative::provocative
::provded::provided
::provicial::provincial
::provinicial::provincial
::provisonal::provisional
::proximty::proximity
::pseudononymous::pseudonymous
::pseudonyn::pseudonym
::psoition::position
::psuedo::pseudo
::psycology::psychology
::psyhic::psychic
::ptogress::progress
::publically::publicly
::publicaly::publicly
::puchasing::purchasing
::Pucini::Puccini
::Puertorrican::Puerto Rican
::Puertorricans::Puerto Ricans
::pulverised::pulverized
::pumkin::pumpkin
::puritannical::puritanical
::purposedly::purposely
::purpotedly::purportedly
::pursuade::persuade
::pursuaded::persuaded
::pursuades::persuades
::pususading::persuading
::puting::putting
::pwoer::power
::pyscic::psychic
::quantaty::quantity
::quantitiy::quantity
::quarantaine::quarantine
::quater::quarter
::quaters::quarters
::quesion::question
::quesions::questions
::questioms::questions
::questiosn::questions
::questoin::question
::questonable::questionable
::quetion::question
::quetions::questions
::quicklyu::quickly
::quinessential::quintessential
::quitted::quit
::quizes::quizzes
::rabinnical::rabbinical
::racaus::raucous
::radiactive::radioactive
::radify::ratify
::raelly::really
::rahter::rather
::rarified::rarefied
::reaccurring::recurring
::reacing::reaching
::reacll::recall
::readmition::readmission
::realitvely::relatively
::realsitic::realistic
::realtions::relations
::realy::really
::realyl::really
::reasearch::research
::rebiulding::rebuilding
::rebllions::rebellions
::rebounce::rebound
::reccomend::recommend
::reccomendations::recommendations
::reccomended::recommended
::reccomending::recommending
::reccommend::recommend
::reccommended::recommended
::reccommending::recommending
::reccuring::recurring
::receeded::receded
::receeding::receding
::receieve::receive
::receivedfrom::received from
::recepient::recipient
::recepients::recipients
::receving::receiving
::rechargable::rechargeable
::reched::reached
::recide::reside
::recided::resided
::recident::resident
::recidents::residents
::reciding::residing
::reciepents::recipients
::reciept::receipt
::recieve::receive
::recieved::received
::reciever::receiver
::recievers::receivers
::recieves::receives
::recieving::receiving
::recipiant::recipient
::recipiants::recipients
::recived::received
::recivership::receivership
::recogise::recognise
::recogize::recognize
::recomend::recommend
::recomendation::recommendation
::recomendations::recommendations
::recomended::recommended
::recomending::recommending
::recomends::recommends
::recommedations::recommendations
::reconaissance::reconnaissance
::reconcilation::reconciliation
::reconize::recognize
::reconized::recognized
::reconnaissence::reconnaissance
::recontructed::reconstructed
::recordproducer::record producer
::recquired::required
::recrational::recreational
::recrod::record
::recuiting::recruiting
::recuring::recurring
::recurrance::recurrence
::rediculous::ridiculous
::reedeming::redeeming
::reenforced::reinforced
::refect::reflect
::refedendum::referendum
::referal::referral
::refered::referred
::referiang::referring
::refering::referring
::refernces::references
::referrence::reference
::referrs::refers
::reffered::referred
::refference::reference
::refrence::reference
::refrences::references
::refrers::refers
::refridgeration::refrigeration
::refridgerator::refrigerator
::refromist::reformist
::refusla::refusal
::regardes::regards
::regluar::regular
::reguarly::regularly
::regulaion::regulation
::regulaotrs::regulators
::regularily::regularly
::rehersal::rehearsal
::reicarnation::reincarnation
::reigining::reigning
::reknown::renown
::reknowned::renowned
::rela::real
::relaly::really
::relatiopnship::relationship
::relativly::relatively
::relected::reelected
::releive::relieve
::releived::relieved
::releiver::reliever
::releses::releases
::relevence::relevance
::relevent::relevant
::reliablity::reliability
::relient::reliant
::religeous::religious
::religous::religious
::religously::religiously
::relinqushment::relinquishment
::relitavely::relatively
::relpacement::replacement
::reluctent::reluctant
::remaing::remaining
::remeber::remember
::rememberable::memorable
::rememberance::remembrance
::remembrence::remembrance
::remenant::remnant
::remenicent::reminiscent
::reminent::remnant
::reminescent::reminiscent
::reminscent::reminiscent
::reminsicent::reminiscent
::rendevous::rendezvous
::rendezous::rendezvous
::renedered::rende
::renewl::renewal
::rentors::renters
::reoccurrence::recurrence
::reommend::recommend
::reorganision::reorganisation
::repentence::repentance
::repentent::repentant
::repeteadly::repeatedly
::repetion::repetition
::repid::rapid
::reponse::response
::reponsible::responsible
::reportadly::reportedly
::represantative::representative
::representativs::representatives
::representive::representative
::representives::representatives
::represetned::represented
::represnt::represent
::reproducable::reproducible
::reprtoire::repertoire
::repsectively::respectively
::reptition::repetition
::requirment::requirement
::requred::required
::resaurant::restaurant
::resembelance::resemblance
::resembes::resembles
::resemblence::resemblance
::reserach::research
::resevoir::reservoir
::resignement::resignment
::resistable::resistible
::resistence::resistance
::resistent::resistant
::resollution::resolution
::resorces::resources
::respectivly::respectively
::respomd::respond
::respomse::response
::responce::response
::responibilities::responsibilities
::responisble::responsible
::responnsibilty::responsibility
::responsability::responsibility
::responsable::responsible
::responsibile::responsible
::responsibilites::responsibilities
::responsiblity::responsibility
::respository::repository
::ressemblance::resemblance
::ressemble::resemble
::ressembled::resembled
::ressemblence::resemblance
::ressembling::resembling
::resssurecting::resurrecting
::ressurect::resurrect
::ressurected::resurrected
::ressurection::resurrection
::ressurrection::resurrection
::restaraunt::restaurant
::restaraunteur::restaurateur
::restaraunteurs::restaurateurs
::restaraunts::restaurants
::restauranteurs::restaurateurs
::restauration::restoration
::restauraunt::restaurant
::resteraunt::restaurant
::resteraunts::restaurants
::resticted::restricted
::restuarant::restaurant
::resturant::restaurant
::resturaunt::restaurant
::resurecting::resurrecting
::retalitated::retaliated
::retalitation::retaliation
::retreive::retrieve
::returnd::returned
::reult::result
::revaluated::reevaluated
::reveiw::review
::reveiwing::reviewing
::reveral::reversal
::reversable::reversible
::revolutionar::revolutionary
::rewitten::rewritten
::rewriet::rewrite
::rhymme::rhyme
::rhythem::rhythm
::rhythim::rhythm
::rhytmic::rhythmic
::rigourous::rigorous
::rininging::ringing
::rised::rose
::Rockerfeller::Rockefeller
::rococco::rococo
::rocord::record
::roomate::roommate
::rougly::roughly
::rucuperate::recuperate
::rudimentatry::rudimentary
::rulle::rule
::rumers::rumors
::runing::running
::runnung::running
::russina::Russian
::Russion::Russian
::rwite::write
::rythem::rhythm
::rythim::rhythm
::rythm::rhythm
::rythmic::rhythmic
::rythyms::rhythms
::sacrafice::sacrifice
::sacreligious::sacrilegious
::sacrifical::sacrificial
::saftey::safety
::safty::safety
::saidhe::said he
::saidit::said it
::saidt he::said the
::saidthat::said that
::saidthe::said the
::salery::salary
::sanctionning::sanctioning
::sandwhich::sandwich
::Sanhedrim::Sanhedrin
::santioned::sanctioned
::sargant::sergeant
::sargeant::sergeant
::satelite::satellite
::satelites::satellites
::Saterday::Saturday
::Saterdays::Saturdays
::satisfactority::satisfactorily
::satric::satiric
::satrical::satirical
::satrically::satirically
::sattelite::satellite
::sattelites::satellites
::saught::sought
::saxaphone::saxophone
::scaleable::scalable
::scandanavia::Scandinavia
::scaricity::scarcity
::scavanged::scavenged
::scedule::schedule
::sceduled::scheduled
::schedual::schedule
::scholarhip::scholarship
::scientfic::scientific
::scientifc::scientific
::scince::science
::scinece::science
::scirpt::script
::scoll::scroll
::screenwrighter::screenwriter
::scrutinity::scrutiny
::scuptures::sculptures
::seach::search
::seached::searched
::seaches::searches
::seance::s�ance
::secratary::secretary
::secretery::secretary
::sectino::section
::sedereal::sidereal
::seeked::sought
::segementation::segmentation
::seguoys::segues
::seh::she
::seige::siege
::seing::seeing
::seinor::senior
::seldomly::seldom
::selectoin::selection
::senarios::scenarios
::sence::sense
::senstive::sensitive
::sensure::censure
::sentance::sentence
::seomthing::something
::separeate::separate
::seperate::separate
::seperated::separated
::seperately::separately
::seperates::separates
::seperating::separating
::seperation::separation
::seperatism::separatism
::seperatist::separatist
::sepina::subpoena
::sercumstances::circumstances
::sergent::sergeant
::settelement::settlement
::settlment::settlement
::severeal::several
::severley::severely
::severly::severely
::sevice::service
::shaddow::shadow
::shcool::school
::she;ll::she'll
::sheild::shield
::sherif::sheriff
::shesaid::she said
::shineing::shining
::shiped::shipped
::shiping::shipping
::shopkeeepers::shopkeepers
::shorly::shortly
::shortwhile::short while
::shoudl::should
::shoudln't::shouldn't
::should of been::should have been
::should of had::should have had
::shouldent::shouldn't
::shouldn;t::shouldn't
::shouldnt::shouldn't
::showinf::showing
::shreak::shriek
::shrinked::shrunk
::sicne::since
::sideral::sidereal
::siezure::seizure
::siezures::seizures
::siginificant::significant
::signficant::significant
::signficiant::significant
::signfies::signifies
::signifacnt::significant
::signifantly::significantly
::significently::significantly
::signifigant::significant
::signifigantly::significantly
::signitories::signatories
::signitory::signatory
::simalar::similar
::similarily::similarly
::similiar::similar
::similiarity::similarity
::similiarly::similarly
::simmilar::similar
::simpley::simply
::simplier::simpler
::simpyl::simply
::simultanous::simultaneous
::simultanously::simultaneously
::sincerley::sincerely
::sincerly::sincerely
::singsog::singsong
::Sionist::Zionist
::Sionists::Zionists
::sitll::still
::Sixtin::Sistine
::Skagerak::Skagerrak
::skateing::skating
::slaugterhouses::slaughterhouses
::slowy::slowly
::smae::same
::smoe::some
::sneeks::sneaks
::snese::sneeze
::socalism::socialism
::socities::societies
::soem::some
::sofware::software
::sohw::show
::soical::social
::soilders::soldiers
::solatary::solitary
::soley::solely
::soliders::soldiers
::soliliquy::soliloquy
::soluable::soluble
::somene::someone
::somethign::something
::someting::something
::somewaht::somewhat
::somthing::something
::somtimes::sometimes
::somwhere::somewhere
::sophicated::sophisticated
::sophmore::sophomore
::sorceror::sorcerer
::sorrounding::surrounding
::sot hat::so that
::sotry::story
::soudn::sound
::soudns::sounds
::sountrack::soundtrack
::sourth::south
::sourthern::southern
::souvenier::souvenir
::souveniers::souvenirs
::soveits::soviets(x
::sovereignity::sovereignty
::soverign::sovereign
::soverignity::sovereignty
::soverignty::sovereignty
::spainish::Spanish
::speach::speech
::specfic::specific
::specificaly::specifically
::specificalyl::specifically
::specifiying::specifying
::speciman::specimen
::spectauclar::spectacular
::spectaulars::spectaculars
::spectum::spectrum
::speices::species
::spendour::splendour
::spermatozoan::spermatozoon
::spoace::space
::sponser::sponsor
::sponsered::sponsored
::spontanous::spontaneous
::sponzored::sponsored
::spoonfulls::spoonfuls
::sppeches::speeches
::spreaded::spread
::sprech::speech
::spred::spread
::spriritual::spiritual
::spritual::spiritual
::sqaure::square
::stablility::stability
::stainlees::stainless
::staion::station
::standars::standards
::stange::strange
::startegic::strategic
::startegies::strategies
::startegy::strategy
::stateman::statesman
::statememts::statements
::statment::statement
::statments::statements
::steriods::steroids
::sterotypes::stereotypes
::stilus::stylus
::stingent::stringent
::stiring::stirring
::stirrs::stirs
::stlye::style
::stnad::stand
::stong::strong
::stopry::story
::storeis::stories
::storise::stories
::stornegst::strongest
::stoyr::story
::stpo::stop
::stradegies::strategies
::stradegy::strategy
::stratagically::strategically
::streemlining::streamlining
::stregth::strength
::strenghen::strengthen
::strenghened::strengthened
::strenghening::strengthening
::strenght::strength
::strenghten::strengthen
::strenghtened::strengthened
::strenghtening::strengthening
::strengtened::strengthened
::strenous::strenuous
::strentgh::strength
::strictist::strictest
::strikely::strikingly
::strnad::strand
::stroy::story
::struggel::struggle
::strugle::struggle
::stubborness::stubbornness
::stucture::structure
::stuctured::structured
::studdy::study
::studing::studying
::studnet::student
::stuggling::struggling
::sturcture::structure
::subcatagories::subcategories
::subcatagory::subcategory
::subconsiously::subconsciously
::subjudgation::subjugation
::submachne::submachine
::subpecies::subspecies
::subsidary::subsidiary
::subsiduary::subsidiary
::subsquent::subsequent
::subsquently::subsequently
::substace::substance
::substancial::substantial
::substatial::substantial
::substituded::substituted
::substract::subtract
::substracted::subtracted
::substracting::subtracting
::substraction::subtraction
::substracts::subtracts
::subtances::substances
::subterranian::subterranean
::suburburban::suburban
::succceeded::succeeded
::succcesses::successes
::succedded::succeeded
::succeded::succeeded
::succeds::succeeds
::succesful::successful
::succesfully::successfully
::succesfuly::successfully
::succesion::succession
::succesive::successive
::successfull::successful
::successfuly::successfully
::successfulyl::successfully
::successully::successfully
::succsess::success
::succsessfull::successful
::suceed::succeed
::suceeded::succeeded
::suceeding::succeeding
::suceeds::succeeds
::sucesful::successful
::sucesfully::successfully
::sucesfuly::successfully
::sucesion::succession
::sucess::success
::sucesses::successes
::sucessful::successful
::sucessfull::successful
::sucessfully::successfully
::sucessfuly::successfully
::sucession::succession
::sucessive::successive
::sucessor::successor
::sucessot::successor
::sucide::suicide
::sucidial::suicidal
::sufferage::suffrage
::sufferred::suffered
::sufferring::suffering
::sufficent::sufficient
::sufficently::sufficiently
::sufficiant::sufficient
::sumary::summary
::sunglases::sunglasses
::suop::soup
::superceeded::superseded
::superintendant::superintendent
::suphisticated::sophisticated
::suplimented::supplemented
::supose::suppose
::suposed::supposed
::suposedly::supposedly
::suposes::supposes
::suposing::supposing
::supplamented::supplemented
::suppliementing::supplementing
::suppoed::supposed
::supposingly::supposedly
::suppossed::supposed
::suppy::supply
::supress::suppress
::supressed::suppressed
::supresses::suppresses
::supressing::suppressing
::suprise::surprise
::suprised::surprised
::suprising::surprising
::suprisingly::surprisingly
::suprize::surprise
::suprized::surprised
::suprizing::surprising
::suprizingly::surprisingly
::surfce::surface
::suround::surround
::surounded::surrounded
::surounding::surrounding
::suroundings::surroundings
::surounds::surrounds
::surplanted::supplanted
::surpress::suppress
::surpressed::suppressed
::surprize::surprise
::surprized::surprised
::surprizing::surprising
::surprizingly::surprisingly
::surrepetitious::surreptitious
::surrepetitiously::surreptitiously
::surreptious::surreptitious
::surreptiously::surreptitiously
::surronded::surrounded
::surrouded::surrounded
::surrouding::surrounding
::surrundering::surrendering
::surveilence::surveillance
::surveill::surveil
::surveyer::surveyor
::surviver::survivor
::survivers::survivors
::survivied::survived
::suseptable::susceptible
::suseptible::susceptible
::suspention::suspension
::svae::save
::svaes::saves
::swaer::swear
::swaers::swears
::swepth::swept
::swiming::swimming
::syas::says
::symetrical::symmetrical
::symetrically::symmetrically
::symetry::symmetry
::symettric::symmetric
::symmetral::symmetric
::symmetricaly::symmetrically
::synagouge::synagogue
::syncronization::synchronization
::synonomous::synonymous
::synonymns::synonyms
::synphony::symphony
::syphyllis::syphilis
::sypmtoms::symptoms
::syrap::syrup
::sysetm::system
::sysmatically::systematically
::sytem::system
::sytle::style
::tabacco::tobacco
::tahn::than
::taht::that
::talekd::talked
::talkign::talking
::targetted::targeted
::targetting::targeting
::tast::taste
::tath::that
::tatoo::tattoo
::tattooes::tattoos
::taxanomic::taxonomic
::taxanomy::taxonomy
::teached::taught
::techician::technician
::techicians::technicians
::techiniques::techniques
::technitian::technician
::technnology::technology
::technolgy::technology
::tecnical::technical
::teh::the
::tehw::the
::tehy::they
::telelevision::television
::televsion::television
::tellt he::tell the
::telphony::telephony
::temerature::temperature
::temparate::temperate
::temperarily::temporarily
::temperment::temperament
::tempermental::temperamental
::tempertaure::temperature
::temperture::temperature
::temprary::temporary
::tenacle::tentacle
::tenacles::tentacles
::tendacy::tendency
::tendancies::tendencies
::tendancy::tendency
::tendonitis::tendinitis
::tennisplayer::tennis player
::tepmorarily::temporarily
::termoil::turmoil
::terrestial::terrestrial
::terriories::territories
::terriory::territory
::territorist::terrorist
::territoy::territory
::terroist::terrorist
::testiclular::testicular
::tghe::the
::tghis::this
::Thanks1::Thanks{!}
::thansk::thanks
::thats::that's
::thatt he::that the
::thatthe::that the
::thecompany::the company
::theese::these
::thefirst::the first
::thegovernment::the government
::theh::the
::theif::thief
::their are::there are
::their is::there is
::theives::thieves
::themself::themselves
::themselfs::themselves
::themslves::themselves
::thenew::the new
::therafter::thereafter
::therby::thereby
::there's is::theirs is
::theri::their
::thesame::the same
::thetwo::the two
::they;l::they'll
::they;ll::they'll
::they;r::they're
::they;re::they're
::they;v::they've
::they;ve::they've
::theyll::they'll
::they're are::there are
::they're is::there is
::theyve::they've
::thgat::that
::thge::the
::thier::their
::thign::thing
::thigns::things
::thigsn::things
::thikn::think
::thikns::thinks
::thisyear::this year
::thiunk::think
::thn::then
::thna::than
::thne::then
::thnig::thing
::thnigs::things
::thoughout::throughout
::threatend::threatened
::threatning::threatening
::threee::three
::threshhold::threshold
::thrid::third
::throrough::thorough
::throughly::thoroughly
::througout::throughout
::throuhg::through
::thru::through
::thsi::this
::thsoe::those
::thta::that
::thw::the
::thyat::that
::tiem::time
::tihkn::think
::tihs::this
::timne::time
::tiogether::together
::tiptoing::tiptoeing
::tje::the
::tjhe::the
::tjpanishad::upanishad
::tkae::take
::tkaes::takes
::tkaing::taking
::tlaking::talking
::tobbaco::tobacco
::todays::today's
::todya::today
::togehter::together
::toghether::together
::toldt he::told the
::tolerence::tolerance
::Tolkein::Tolkien
::tomatos::tomatoes
::tommorow::tomorrow
::tommorrow::tomorrow
::tomorow::tomorrow
::tongiht::tonight
::tonihgt::tonight
::toriodal::toroidal
::tormenters::tormentors
::torpeados::torpedoes
::torpedos::torpedoes
::tot he::to the
::totaly::totally
::totalyl::totally
::tothe::to the
::toubles::troubles
::tought::tough
::tounge::tongue
::tournies::tourneys
::towords::towards
::towrad::toward
::tradionally::traditionally
::traditionaly::traditionally
::traditionalyl::traditionally
::traditionnal::traditional
::traditition::tradition
::tradtionally::traditionally
::trafficed::trafficked
::trafficing::trafficking
::trafic::traffic
::trancendent::transcendent
::trancending::transcending
::tranform::transform
::tranformed::transformed
::transcendance::transcendence
::transcendant::transcendent
::transcendentational::transcendental
::transending::transcending
::transesxuals::transsexuals
::transfered::transferred
::transfering::transferring
::transformaton::transformation
::transistion::transition
::translater::translator
::translaters::translators
::transmissable::transmissible
::transporation::transportation
::travelling::traveling
::tremelo::tremolo
::tremelos::tremolos
::triguered::triggered
::triology::trilogy
::troling::trolling
::troup::troupe
::truely::truly
::truley::truly
::trustworthyness::trustworthiness
::tryed::tried
::tthe::the
::Tuscon::Tucson
::tust::trust
::twon::town
::twpo::two
::tyhat::that
::tyhe::the
::tyhe::they
::typcial::typical
::typicaly::typically
::tyranies::tyrannies
::tyrany::tyranny
::tyrranies::tyrannies
::tyrrany::tyranny
::ubiquitious::ubiquitous
::udnerstand::understand
::uise::use
::Ukranian::Ukrainian
::ultimely::ultimately
::unacompanied::unaccompanied
::unahppy::unhappy
::unanymous::unanimous
::unathorised::unauthorised
::unavailible::unavailable
::unballance::unbalance
::unbeleivable::unbelievable
::uncertainity::uncertainty
::unchallengable::unchallengeable
::unchangable::unchangeable
::uncompetive::uncompetitive
::unconcious::unconscious
::unconciousness::unconsciousness
::unconfortability::discomfort
::uncontitutional::unconstitutional
::unconvential::unconventional
::undecideable::undecidable
::understnad::understand
::understoon::understood
::undert he::under the
::undesireable::undesirable
::undetecable::undetectable
::undoubtely::undoubtedly
::undreground::underground
::uneccesary::unnecessary
::unecessary::unnecessary
::unequalities::inequalities
::unfocussed::unfocused
::unforetunately::unfortunately
::unforgetable::unforgettable
::unforgiveable::unforgivable
::unfortunatley::unfortunately
::unfortunatly::unfortunately
::unfourtunately::unfortunately
::unihabited::uninhabited
::unilateraly::unilaterally
::unilatreal::unilateral
::unilatreally::unilaterally
::uninterruped::uninterrupted
::uninterupted::uninterrupted
::UnitedStates::United States
::UnitesStates::UnitedStates
::univeral::universal
::univeristies::universities
::univeristy::university
::universtiy::university
::univesities::universities
::univesity::university
::unkown::unknown
::unliek::unlike
::unlikey::unlikely
::unmistakeably::unmistakably
::unneccesarily::unnecessarily
::unneccesary::unnecessary
::unneccessarily::unnecessarily
::unneccessary::unnecessary
::unnecesarily::unnecessarily
::unnecesary::unnecessary
::unoffical::unofficial
::unoperational::nonoperational
::unoticeable::unnoticeable
::unplease::displease
::unpleasently::unpleasantly
::unplesant::unpleasant
::unprecendented::unprecedented
::unprecidented::unprecedented
::unrepentent::unrepentant
::unrepetant::unrepentant
::unrepetent::unrepentant
::unsubstanciated::unsubstantiated
::unsuccesful::unsuccessful
::unsuccesfully::unsuccessfully
::unsuccessfull::unsuccessful
::unsucesful::unsuccessful
::unsucesfuly::unsuccessfully
::unsucessful::unsuccessful
::unsucessfull::unsuccessful
::unsucessfully::unsuccessfully
::unsuprised::unsurprised
::unsuprising::unsurprising
::unsuprisingly::unsurprisingly
::unsuprized::unsurprised
::unsuprizing::unsurprising
::unsuprizingly::unsurprisingly
::unsurprized::unsurprised
::unsurprizing::unsurprising
::unsurprizingly::unsurprisingly
::untill::until
::untilll::until
::untranslateable::untranslatable
::unuseable::unusable
::unusuable::unusable
::unviersity::university
::unwarrented::unwarranted
::unweildly::unwieldy
::unwieldly::unwieldy
::upcomming::upcoming
::upgradded::upgraded
::usally::usually
::useable::usable
::useage::usage
::usefull::useful
::usefuly::usefully
::useing::using
::usualy::usually
::usualyl::usually
::ususally::usually
::vaccum::vacuum
::vaccume::vacuum
::vacinity::vicinity
::vaguaries::vagaries
::vaieties::varieties
::vailidty::validity
::valetta::valletta
::valuble::valuable
::valueable::valuable
::varations::variations
::varient::variant
::variey::variety
::varing::varying
::varities::varieties
::varity::variety
::vasall::vassal
::vasalls::vassals
::vegatarian::vegetarian
::vegitable::vegetable
::vegitables::vegetables
::vegtable::vegetable
::vehicule::vehicle
::vell::well
::venemous::venomous
::vengance::vengeance
::vengence::vengeance
::verfication::verification
::verison::version
::verisons::versions
::vermillion::vermilion
::versitilaty::versatility
::versitlity::versatility
::vetween::between
::veyr::very
::vigilence::vigilance
::vigourous::vigorous
::villian::villain
::villification::vilification
::villify::vilify
::vincinity::vicinity
::violentce::violence
::virtualyl::virtually
::virutal::virtual
::visable::visible
::visably::visibly
::vis-a-vis::vis-�-vis
::visting::visiting
::vistors::visitors
::vitories::victories
::volcanoe::volcano
::voleyball::volleyball
::volontary::voluntary
::volonteer::volunteer
::volonteered::volunteered
::volonteering::volunteering
::volonteers::volunteers
::volounteer::volunteer
::volounteered::volunteered
::volounteering::volunteering
::volounteers::volunteers
::vreity::variety
::vrey::very
::vriety::variety
::vulnerablility::vulnerability
::vulnerible::vulnerable
::vyer::very
::vyre::very
::wa snot::was not
::waht::what
::wanna::want to
::warantee::warranty
::wardobe::wardrobe
::warrent::warrant
::warrriors::warriors
::wasnt::wasn't
::wass::was
::watn::want
::wayword::wayward
::we;d::we'd
::we;ll::we'll
::we;re::we're
::we;ve::we've
::weaponary::weaponry
::weas::was
::weekned::weekend
::wehn::when
::weilded::wielded
::wendsay::Wednesday
::wensday::Wednesday
::wereabouts::whereabouts
::wern't::weren't
::werre::were
::whant::want
::whants::wants
::what;s::what's
::whcih::which
::whent he::when the
::wheras::whereas
::where;s::where's
::wherease::whereas
::whereever::wherever
::wherre::where
::whic::which
::whicht he::which the
::whihc::which
::whith::with
::whlch::which
::whn::when
::who;s::who's
::who;ve::who've
::wholey::wholly
::whta::what
::whther::whether
::widesread::widespread
::wief::wife
::wierd::weird
::wiew::view
::wih::with
::wihch::which
::wiht::with
::will of been::will have been
::will of had::will have had
::willbe::will be
::wille::will
::willingless::willingness
::windoes::windows
::wintery::wintry
::wirting::writing
::witha::with a
::withe::with
::witheld::withheld
::withing::within
::withold::withhold
::witht he::with the
::witht::with
::withthe::with the
::witn::with
::wiull::will
::wnat::want
::wnated::wanted
::wnats::wants
::woh::who
::wohle::whole
::wokr::work
::wokring::working
::womens::women's
::won;t::won't
::wonderfull::wonderful
::wo'nt::won't
::workststion::workstation
::worls::world
::worstened::worsened
::woudl::would
::woudln't::wouldn't
::would of been::would have been
::would of had::would have had
::wouldbe::would be
::wouldn;t::wouldn't
::wouldnt::wouldn't
::wresters::wrestlers
::wriet::write
::writen::written
::writting::writing
::wrod::word
::wroet::wrote
::wrok::work
::wroking::working
::ws::was
::wtih::with
::wuould::would
::wupport::support
::wya::way
::xenophoby::xenophobia
::yaching::yachting
::yatch::yacht
::yeasr::years
::yeild::yield
::yeilding::yielding
::yera::year
::yeras::years
::yersa::years
::yoiu::you
::yoru::your
::you;d::you'd
::you;re::you're
::youare::you are
::your a::you're a
::your an::you're an
::your her::you're her
::your here::you're here
::your his::you're his
::your my::you're my
::your the::you're the
::your their::you're their
::your your::you're your
::you're own::your own
::youseff::yousef
::youself::yourself
::youve::you've
::ytou::you
::yuo::you
::yuor::your
::zeebra::zebra
return

Hexify(x) ;Stolen from Autoclip/Laszlo 
{ 
  StringLen,len,x 
  format=%A_FormatInteger% 
  SetFormat,Integer,Hex 
  hex= 
  Loop,%len% 
  { 
    Transform,y,Asc,%x% 
    StringTrimLeft,y,y,2 
    hex=%hex%%y% 
    StringTrimLeft,x,x,1 
  } 
  SetFormat,Integer,%format% 
  Return,hex
} 

DeHexify(x) 
{ 
   StringLen,len,x 
   ;len:=(len-4)/2 
   string= 
   Loop,%len% 
   { 
      StringLeft,hex,x,2
      hex=0x%hex% 
      Transform,y,Chr,%hex% 
      string=%string%%y% 
      StringTrimLeft,x,x,2 
   } 
   Return,string 
} 


EXIT: 
ExitApp 