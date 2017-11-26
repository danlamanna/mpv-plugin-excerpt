-- This script allows to create excerpts of a video that is played,
-- press "i" to mark the begin of the range to excerpt,
-- press "o" to mark the end   of the range to excerpt,
-- press "I" to continue playback at the "begin" location,
-- press "O" to jump to the "end" location and pause there,
-- press "x" to actually start the creation of the excerpt,
--  which will be done by starting an external executable
--  named "excerpt_copy" with the parameters $1 = begin,
--  $2 = duration, $3 = source file name
-- (see bottom of this file for all key bindings)

-- initialization:

utils = require 'mp.utils'

excerpt_begin = 0.0
excerpt_end   = mp.get_property_native("length")
if excerpt_end == nil then
   excerpt_end = 0.0
end


mp.set_property("hr-seek-framedrop","no")
mp.set_property("options/keep-open","always")

-- alas, the following setting seems to not take effect - needs
-- to be specified on the command line of mpv, instead:
mp.set_property("options/script-opts","osc-layout=bottombar,osc-hidetimeout=120000")


local function excerpt_on_eof()
   -- pause upon reaching the end of the file
   mp.msg.log("info", "playback reached end of file")
   mp.set_property("pause","yes")
   mp.commandv("seek", 100, "absolute-percent", "exact")
end
mp.register_event("eof-reached", excerpt_on_eof)

-- range marking

local function excerpt_rangemessage()
   local duration = excerpt_end - excerpt_begin
   local message = ""
   message = message .. "begin=" .. string.format("%4.3f", excerpt_begin) .. "s "
   message = message .. "end=" .. string.format("%4.3f", excerpt_end) .. "s "
   message = message .. "duration=" .. string.format("% 4.3f", duration) .. "s "
   return message
end

local function excerpt_rangeinfo()
   local message = excerpt_rangemessage()
   mp.msg.log("info", message)
   mp.osd_message(message, 5)
end

local function excerpt_mark_begin_handler()
   local pt = mp.get_property_native("playback-time")

   -- at some later time, setting a/b markers might be used to visualize begin/end
   -- mp.set_property("ab-loop-a", pt)
   -- mp.set_property("loop", 999)

   excerpt_begin = pt
   if excerpt_begin > excerpt_end then
      excerpt_end = excerpt_begin
   end

   excerpt_rangeinfo()
end

local function excerpt_mark_end_handler()
   local pt = mp.get_property_native("playback-time")

   -- at some later time, setting a/b markers might be used to visualize begin/end
   -- mp.set_property("ab-loop-b", pt)
   -- mp.set_property("loop", 999)

   excerpt_end = pt
   if excerpt_end < excerpt_begin then
      excerpt_begin = excerpt_end
   end

   excerpt_rangeinfo()
end

-- writing

local function excerpt_write_handler()
   if excerpt_begin == excerpt_end then
      message = "excerpt_write: not writing because begin == end == " .. excerpt_begin
      mp.osd_message(message, 3)
      return
   end

   -- determine file name

   local cwd = utils.getcwd()
   local direntries = utils.readdir(cwd)
   local ftable = {}
   for i = 1, #direntries do
      -- mp.msg.log("info", "direntries[" .. i .. "] = " .. direntries[i])
      ftable[direntries[i]] = 1
   end

   local fname = ""
   for i=0,999 do
      local f = string.format("excerpt_%03d.mp4", i)

      -- mp.msg.log("info", "ftable[" .. f .. "] = " .. direntries[f])

      if ftable[f] == nil then
         fname = f
         break
      end
   end
   if fname == "" then
      message = "not writing because all filenames already in use"
      mp.osd_message(message, 10)
      return
   end

   duration = excerpt_end - excerpt_begin

   local srcname = mp.get_property_native("path")

   local message = excerpt_rangemessage()
   message = message .. "writing excerpt of source file '" .. srcname .. "'\n"
   message = message .. "to destination file '" .. fname .. "'"
   mp.msg.log("info", message)
   mp.osd_message(message, 10)

   local p = {}
   p["cancellable"] = false
   p["args"] = {}
   p["args"][1] = "excerpt_copy"
   p["args"][2] = tostring(excerpt_begin)
   p["args"][3] = tostring(duration)
   p["args"][4] = tostring(srcname)
   p["args"][5] = tostring(fname)

   local res = utils.subprocess(p)

   if (res["error"] ~= nil) then
      local message = "failed to run excerpt_copy\nerror message: " .. res["error"]
      message = message .. "\nstatus = " .. res["status"] .. "\nstdout = " .. res["stdout"]
      mp.msg.log("error", message)
      mp.osd_message(message, 10)
   else
      mp.msg.log("info", "excerpt '" .. fname .. "' written.")
      message = message .. "... done."
      mp.osd_message(message, 10)
   end
end

-- seeking
local function excerpt_seek_begin_handler()
   mp.commandv("seek", excerpt_begin, "absolute", "exact")
end

local function excerpt_seek_end_handler()
   mp.commandv("seek", excerpt_end, "absolute", "exact")
end

local function excerpt_on_loaded()
   mp.set_property("pause","yes")
end

mp.register_event("file-loaded", excerpt_on_loaded)

mp.add_key_binding("i", "excerpt_mark_begin", excerpt_mark_begin_handler)
mp.add_key_binding("shift+i", "excerpt_seek_begin", excerpt_seek_begin_handler)
mp.add_key_binding("o", "excerpt_mark_end", excerpt_mark_end_handler)
mp.add_key_binding("shift+o", "excerpt_seek_end", excerpt_seek_end_handler)
mp.add_key_binding("x", "excerpt_write", excerpt_write_handler)

excerpt_rangeinfo()
