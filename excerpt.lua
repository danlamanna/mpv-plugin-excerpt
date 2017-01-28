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




function excerpt_rangemessage()
        local duration = excerpt_end - excerpt_begin
        local message = ""
        message = message .. "begin=" .. string.format("%4.3f", excerpt_begin) .. "s "
        message = message .. "end=" .. string.format("%4.3f", excerpt_end) .. "s "
        message = message .. "duration=" .. string.format("% 4.3f", duration) .. "s "
        return message
end

function excerpt_rangeinfo()
        local message = excerpt_rangemessage()
        mp.msg.log("info", message)
        mp.osd_message(message, 5)
end

function excerpt_mark_begin_handler()
        pt = mp.get_property_native("playback-time")

        -- at some later time, setting a/b markers might be used to visualize begin/end
        -- mp.set_property("ab-loop-a", pt)
        -- mp.set_property("loop", 999)

        excerpt_begin = pt
        if excerpt_begin > excerpt_end then
                excerpt_end = excerpt_begin
        end

        excerpt_rangeinfo()
end

function excerpt_mark_end_handler()
        pt = mp.get_property_native("playback-time")

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

function excerpt_write_handler()
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

        local srcname = mp.get_property_native("path")
        local fname = ""
        for i=0,999 do
                local f = string.format(srcname .. "_excerpt_%03d.mkv", i)

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

        -- mp.commandv("run", "jimbobexcerpt_copy", excerpt_begin, duration, srcname, fname)
end

function excerpt_seek_begin_handler()
        mp.commandv("seek", excerpt_begin, "absolute", "exact")
end

function excerpt_seek_end_handler()
        mp.commandv("seek", excerpt_end, "absolute", "exact")
end

--

mp.add_key_binding("i", "excerpt_mark_begin", excerpt_mark_begin_handler)
mp.add_key_binding("shift+i", "excerpt_seek_begin", excerpt_seek_begin_handler)
mp.add_key_binding("o", "excerpt_mark_end", excerpt_mark_end_handler)
mp.add_key_binding("shift+o", "excerpt_seek_end", excerpt_seek_end_handler)
mp.add_key_binding("x", "excerpt_write", excerpt_write_handler)


function excerpt_on_eof()
        -- pause upon reaching the end of the file
   mp.msg.log("info", "playback reached end of file")

   local filename = mp.get_property_native("path")
   local timepos = mp.get_property_native("time-pos")
   local fh = io.open('processed_files.txt', "a")

   fh:write(filename, "\n")

   io.close(fh)


        mp.set_property("pause","yes")
        --mp.commandv("seek", 100, "absolute-percent", "exact")
end
-- mp.register_event("end-file", excerpt_on_eof)

excerpt_rangeinfo()
