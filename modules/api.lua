---------- { imports } ----------

local lunajson = require("lunajson");

---------- { variables } ----------

local API, download = {}, nil;
local flare_strength = {
    A = 0.001,
    B = 0.01,
    C = 0.1,
    M = 1,
    X = 10
};

-- NOTICE: FFI code was written by Claude Opus 5.5, not hand-coded!
local thread_code = [[
    require("love.thread");

    local ffi = require("ffi");
    local command, channel = ...;

    local function run_hidden(command_line)
        ffi.cdef [=[
            typedef struct {
                uint32_t cb;
                void *reserved, *desktop, *title;
                uint32_t x, y, width, height, x_chars, y_chars, fill, flags;
                uint16_t show_window, reserved_size;
                void *reserved_data, *input, *output, *error;
            } STARTUPINFOA;

            typedef struct {
                void *process, *thread;
                uint32_t process_id, thread_id;
            } PROCESS_INFORMATION;

            int CreateProcessA(const char *, char *, void *, void *, int, uint32_t, void *, const char *, STARTUPINFOA *, PROCESS_INFORMATION *);
            uint32_t WaitForSingleObject(void *, uint32_t);
            int GetExitCodeProcess(void *, uint32_t *);
            int CloseHandle(void *);
        ]=];

        local startup, process, exit_code = ffi.new("STARTUPINFOA"), ffi.new("PROCESS_INFORMATION"), ffi.new("uint32_t[1]", 1);
        startup.cb = ffi.sizeof(startup);

        if (ffi.C.CreateProcessA(nil, ffi.new("char[?]", #command_line + 1, command_line), nil, nil, 0, 0x08000000, nil, nil, startup, process) == 0) then
            return false;
        end

        ffi.C.WaitForSingleObject(process.process, 0xFFFFFFFF);
        ffi.C.GetExitCodeProcess(process.process, exit_code);
        ffi.C.CloseHandle(process.thread);
        ffi.C.CloseHandle(process.process);

        return exit_code[0] == 0;
    end

    local success;

    if (ffi.os == "Windows") then
        success = run_hidden(command);
    else
        local result = os.execute(command);
        success = result == 0 or result == true;
    end

    love.thread.getChannel(channel):push(success);
]];

---------- { helpers } ----------

function API.strength(class)
    return (class and flare_strength[class:sub(1, 1)] * tonumber(class:sub(2))) or 0;
end

local function day_of(days, timestamp)
    local key = timestamp:sub(1, 10);
    days[key] = days[key] or {};

    return days[key];
end

local function decode(contents)
    local ok, result = pcall(lunajson.decode, contents or "");
    return ok and type(result) == "table" and result or nil;
end

---------- { main } ----------

function API.parse(responses)
    local days = {};

    for _, flare in next, responses.flares do
        local day = day_of(days, flare.peakTime);

        if (API.strength(flare.classType) > API.strength(day.flare)) then
            day.flare = flare.classType;
        end
    end

    for _, cme in next, responses.cmes do
        local day = day_of(days, cme.startTime);

        for _, analysis in next, cme.cmeAnalyses or {} do
            for _, simulation in next, (analysis.isMostAccurate and analysis.enlilList) or {} do
                if (simulation.estimatedShockArrivalTime and (analysis.speed or 0) > (day.cme and day.cme.speed or 0)) then
                    day.cme = {
                        speed = analysis.speed,
                        arrival = simulation.estimatedShockArrivalTime:sub(1, 10)
                    };
                end
            end
        end
    end

    for _, particle_event in next, responses.particles do
        day_of(days, particle_event.eventTime).particles = true;
    end

    for _, storm in next, responses.storms do
        for _, reading in next, storm.allKpIndex or {} do
            local day = day_of(days, reading.observedTime);
            day.kp = math.max(day.kp or 0, reading.kpIndex);
        end
    end

    return days;
end

function API.read(folder, files)
    local responses = {};

    for name, file in next, files do
        responses[name] = decode(love.filesystem.read(folder .. "/" .. file));

        if (not responses[name]) then
            return nil;
        end
    end

    return responses;
end

function API.download(properties)
    if (download or love.system.getOS() == "Web") then
        return false;
    end

    local curl = (love.system.getOS() == "Windows" and "C:\\Windows\\System32\\curl.exe") or "curl";
    local folder = properties.cache .. "/download";
    local command = curl .. " -s -f -m 60";

    love.filesystem.createDirectory(folder);

    for _, file in next, properties.files do
        local target = love.filesystem.getSaveDirectory() .. "/" .. folder .. "/" .. file;
        command = command ..
        " -o \"" .. target .. "\" \"" .. properties.url .. file:gsub("%.json$", "") .. properties.query .. "\"";
    end

    download = properties;
    download.folder = folder;
    download.channel = "api_download";
    love.thread.newThread(thread_code):start(command, download.channel);

    return true;
end

function API.update()
    local success = download and love.thread.getChannel(download.channel):pop();

    if (success == nil) then
        return;
    end

    local finished, responses = download, success and API.read(download.folder, download.files);
    download = nil;

    for _, file in next, finished.files do
        local path = finished.folder .. "/" .. file;

        if (responses) then
            love.filesystem.write(finished.cache .. "/" .. file, love.filesystem.read(path));
        end

        love.filesystem.remove(path);
    end

    if (responses) then
        finished.done(responses);
    end
end

return API;
