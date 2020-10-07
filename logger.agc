// Project: AppGameKit-VoxelEngine
// File: logger.agc
// Created: 20-09-06

// Log file
#constant VOXEL_LOG_FILE = "agk_voxel_engine.log"

// Log level
#constant VOXEL_INFO 	= "NOTICE"
#constant VOXEL_WARNING 	= "WARNING"
#constant VOXEL_ERROR 	= "ERROR"

// Globals
global voxel_logger_fid as integer
global voxel_logger_time_check as integer


/**
 * Voxel_Logger_Start(): Append a line to the log file on run-time.
 *
 * It needs to be invoked only ONE TIME before Voxel_Logger_Stop() \
 * then you can reuse it again as many times you need.
 *
 * At this point the log file is open so you cannot reuse the function without a stop.
 * 
 */
function Voxel_Logger_Start()
	voxel_logger_time_check = 0 // Reset every time the log is restarted
	voxel_logger_fid = OpenToWrite (VOXEL_LOG_FILE, 1) // Append the file if exists
	Voxel_Logger_Log("START", VOXEL_INFO, VOXEL_LOG_FILE) // Elapsed time check at start
endfunction


/**
 * Voxel_Logger_Log(): Append a line to the log file on run-time.
 *
 * It needs to be invoked always AFTER Voxel_Logger_Start().
 *
 * @param state$ as string : A readable name to identify the current system state
 * @param info$ as string : Log level. The possible values are, VOXEL_INFO, VOXEL_WARNING, VOXEL_ERROR
 * @param message$ as string : A custom message string
 */
function Voxel_Logger_Log(state$ as string, info$ as string, message$ as string)
	local elapsed as integer
	elapsed = Timer() - voxel_logger_time_check
	WriteLine (voxel_logger_fid, "[" + state$ + "]" + "[" + info$ + "] " + message$ + " (" + Str(elapsed) + ") ")
endfunction


/**
 * Voxel_Logger_Stop(): Closes the current log file.
 *
 * It needs to be invoked always AFTER Voxel_Logger_Start().
 *
 * At this point the log file is closed so you cannot reuse the function without a new start.
 *
 * @param i as integer : timer check enabled 0 No 1 Yes
 */
function Voxel_Logger_Stop()
	Voxel_Logger_Log("STOP", VOXEL_INFO, VOXEL_LOG_FILE) // Elapsed time check at stop
	CloseFile (voxel_logger_fid)
endfunction
