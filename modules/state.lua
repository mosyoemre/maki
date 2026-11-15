---------- { imports } ----------

local flux = require("libraries.flux");
local API = require("modules.api");

---------- { state } ----------

local State = {
    scene = "menu",
    paused = false,
    screen = {
        fade = 0,
        scale = 1,
        offset_x = 0,
        offset_y = 0,
        width = 1920,
        height = 1080,
        fading = false,
        view_height = 990
    },
    menu = {
        music = true,
        camera_y = 0,
        page = "main"
    },
    hand = {
        shade = 0,
        cards = {},
        picking = false
    },
    donki = {
        cache = "donki",
        folder = "modules/data/donki",
        url = "https://ccmc.gsfc.nasa.gov/DONKI-API/get/",
        query = "?startDate=2024-04-10&endDate=2024-05-12",
        files = {
            cmes = "CME.json",
            storms = "GST.json",
            particles = "SEP.json",
            flares = "FLR.json"
        }
    },
    rules = {
        hunger = 6,
        storm_kp = 8,
        panel_power = 1,
        fast_cme = 1000,
        big_flare = "M5.0",
        harvest_health = 4,
        no_power_damage = 20,
        greenhouse_health = 2,
        life_support_power = 3,
        upgrade_every = {5, 7},
        start_date = {
            day = 10,
            month = 4,
            year = 2024
        }
    },
    colors = {
        primary = {192 / 255, 115 / 255, 81 / 255},
        primary_dark = {140 / 255, 78 / 255, 52 / 255},
        secondary = {255 / 255, 255 / 255, 255 / 255},
        dark = {18 / 255, 13 / 255, 13 / 255},
        power = {250 / 255, 204 / 255, 64 / 255},
        health = {250 / 255, 128 / 255, 140 / 255},
        radiation = {179 / 255, 242 / 255, 77 / 255},
        material = {115 / 255, 191 / 255, 250 / 255},
        food = {115 / 255, 217 / 255, 102 / 255},
        danger = {242 / 255, 64 / 255, 51 / 255},
        trophy = {255 / 255, 196 / 255, 37 / 255},
        black = {0, 0, 0}
    },
    limits = {
        power = {0, 30},
        health = {0, 100},
        panels = {1, 6},
        material = {1, 4},
        radiation = {0, 100},
        greenhouse = {0, 3}
    },
    radiation_levels = {
        {
            from = 0,
            damage = 0,
            multiplier = 1
        },
        {
            from = 30,
            damage = 2,
            multiplier = 1.5
        },
        {
            from = 70,
            damage = 5,
            multiplier = 2
        }
    },
    materials = {
        {
            radiation = 4,
            name = "PLAIN",
            image = "plain"
        },
        {
            radiation = 2,
            name = "ALUMINIUM",
            image = "aluminium"
        },
        {
            radiation = 1,
            name = "IRON",
            image = "iron"
        },
        {
            radiation = 0,
            name = "TITANIUM",
            image = "titanium"
        }
    },
    cards = {
        {
            type = "power",
            cost = 0,
            icon = "clean_panel",
            name = "Clean Panels",
            description = "Dust blocks sunlight. Go outside and wipe it off.",
            effects = {
                {
                    resource = "power",
                    amount = 4,
                    delay = 1
                },
                {
                    resource = "radiation",
                    amount = 2
                }
            },
            fact = "In 2018 a giant dust storm covered the solar panels of the Opportunity rover.",
            source = "NASA - Opportunity mission"
        },
        {
            type = "power",
            cost = 6,
            icon = "solar_panel",
            name = "New Solar Panel",
            description = "More power every day from now on.",
            effects = {
                {
                    resource = "panels",
                    amount = 1
                }
            },
            fact = "Mars gets less than half the sunlight Earth does, so Mars bases need big solar arrays.",
            source = "NASA - Mars surface power studies"
        },
        {
            type = "power",
            cost = 0,
            icon = "save_power",
            name = "Power Saving",
            description = "Turn the heaters down. Saves power, but the crew is cold.",
            effects = {
                {
                    resource = "power",
                    amount = 4
                },
                {
                    resource = "health",
                    amount = -8
                }
            },
            fact = "Nights on Mars can drop below -70 C, so heating uses a lot of power.",
            source = "NASA - Curiosity REMS weather station"
        },
        {
            cost = 3,
            upgrade = 2,
            type = "material",
            icon = "aluminium_plate",
            name = "Aluminium Walls",
            description = "Light metal walls. Radiation drops to 2 a day.",
            effects = {
                {
                    resource = "material",
                    amount = 1
                }
            },
            fact = "The walls of the International Space Station are mostly made of aluminium.",
            source = "NASA - International Space Station"
        },
        {
            cost = 5,
            upgrade = 3,
            type = "material",
            icon = "iron_plate",
            name = "Iron Walls",
            description = "Thick, heavy walls. Radiation drops to 1 a day.",
            effects = {
                {
                    resource = "material",
                    amount = 1
                }
            },
            fact = "Mars is red because its soil is full of rusty iron.",
            source = "NASA - Mars facts"
        },
        {
            cost = 8,
            upgrade = 4,
            type = "material",
            icon = "titanium_plate",
            name = "Titanium Walls",
            description = "No radiation gets in, even in a storm!",
            effects = {
                {
                    resource = "material",
                    amount = 1
                }
            },
            fact = "NASA's Juno spacecraft keeps its computer inside a titanium vault to protect it from radiation.",
            source = "NASA - Juno mission"
        },
        {
            type = "food",
            cost = 3,
            icon = "plant_potato",
            name = "Plant Potatoes",
            description = "Lots of food later. You must wait for it to grow.",
            effects = {
                {
                    resource = "health",
                    amount = 22,
                    delay = 3
                }
            },
            fact = "Potatoes are a top crop idea for Mars: lots of food from little space.",
            source = "CSA - Food production on the Moon and in remote areas"
        },
        {
            type = "food",
            cost = 2,
            icon = "grow_lettuce",
            name = "Grow Lettuce",
            description = "Fresh food today. Not very filling.",
            effects = {
                {
                    resource = "health",
                    amount = 8
                }
            },
            fact = "In 2015 astronauts ate lettuce grown on the ISS in NASA's Veggie garden.",
            source = "NASA - Veggie experiment"
        },
        {
            type = "food",
            cost = 5,
            icon = "greenhouse",
            name = "Greenhouse",
            description = "Grow more food every day from now on.",
            effects = {
                {
                    resource = "greenhouse",
                    amount = 1
                }
            },
            fact = "Plants also clean the air: they take in carbon dioxide and give out oxygen.",
            source = "NASA - Advanced Plant Habitat"
        },
        {
            type = "health",
            cost = 4,
            icon = "oxygen_maker",
            name = "Oxygen Maker",
            description = "Split water to make fresh air for the crew.",
            effects = {
                {
                    resource = "health",
                    amount = 18
                }
            },
            fact = "The ISS makes oxygen by splitting water with electricity.",
            source = "NASA - ISS life support system"
        },
        {
            type = "health",
            cost = 2,
            icon = "moxie_air",
            name = "MOXIE Air",
            description = "Make air from Mars air! Only a little.",
            effects = {
                {
                    resource = "health",
                    amount = 9
                }
            },
            fact = "NASA's MOXIE on the Perseverance rover made oxygen from the air of Mars.",
            source = "NASA - Perseverance MOXIE experiment"
        },
        {
            type = "health",
            cost = 0,
            icon = "rest_day",
            name = "Rest Day",
            description = "Sleep and exercise. Nothing gets built.",
            effects = {
                {
                    resource = "health",
                    amount = 6
                }
            },
            fact = "In space, muscles and bones get weaker, so astronauts exercise about 2 hours a day.",
            source = "NASA OSDR - spaceflight muscle and bone studies"
        }
    }
};

---------- { events } ----------

local listeners = {};

local function fire_event(event, ...)
    for _, callback in next, listeners[event] or {} do
        callback(...);
    end
end

function State.on(event, callback)
    listeners[event] = listeners[event] or {};
    table.insert(listeners[event], callback);
end

function State.after(days, callback)
    local schedule, day = State.run.schedule, State.run.day + days;
    schedule[day] = schedule[day] or {};

    table.insert(schedule[day], callback);
end

---------- { helpers } ----------

function State.colors.to_tuple(color, alpha, dim)
    local dim = dim or 1;
    return color[1] * dim, color[2] * dim, color[3] * dim, alpha or 1;
end

function State.date(format, day)
    local start = State.rules.start_date;

    return os.date(format or "%m-%d-%Y", os.time({
        hour = 12,
        year = start.year,
        month = start.month,
        day = start.day + (day or State.run.day) - 1
    }));
end

function State.month_day(iso_date)
    local year, month, day = iso_date:match("(%d+)-(%d+)-(%d+)");

    return os.date("%B ", os.time({
        hour = 12,
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day)
    })) .. tonumber(day);
end

local function use_space_weather(responses, label)
    local rules, storm = State.rules, {
        length = 0
    };

    State.space_weather, State.donki.status = API.parse(responses), label;

    for day = 1, 366 do
        local weather = State.space_weather[State.date("%Y-%m-%d", day)] or {};

        if ((weather.kp or 0) >= rules.storm_kp) then
            storm.day, storm.length = storm.day or day, storm.length + 1;
        elseif (storm.day) then
            break;
        end
    end

    assert(storm.day, "[state.lua] No storm found in the space weather data");

    local storm_date = State.date("%Y-%m-%d", storm.day);

    for day = 1, storm.day do
        local cme = (State.space_weather[State.date("%Y-%m-%d", day)] or {}).cme;

        if (cme and cme.speed >= rules.fast_cme and cme.arrival >= storm_date) then
            storm.warning = day;
            break;
        end
    end

    storm.warning = storm.warning or 1;
    rules.storm, rules.days = storm, storm.day + storm.length - 1;
end

function State.load_space_weather()
    local donki = State.donki;
    local responses = API.read(donki.cache, donki.files) or API.read(donki.folder, donki.files);

    assert(responses, "[state.lua] The built-in DONKI data is missing");
    use_space_weather(responses, "NASA Data: loaded");

    API.download {
        url = donki.url,
        query = donki.query,
        files = donki.files,
        cache = donki.cache,
        done = function(responses)
            use_space_weather(responses, "NASA Data: fetched");
        end
    };
end

local function report_space_weather()
    local run = State.run;
    local weather, dose = State.space_weather[State.date("%Y-%m-%d")] or {}, State.materials[run.material].radiation;
    local dangerous = weather.particles or (weather.flare and weather.flare:sub(1, 1) == "X");
    local reported = API.strength(weather.flare) >= API.strength(State.rules.big_flare);
    local blackout = reported and weather.flare:sub(1, 1) == "M";

    if (reported) then
        table.insert(run.report, "NASA DONKI: " .. weather.flare .. " solar flare today!" .. (blackout and " Radio blackout!" or ""));
    end

    if (weather.cme and weather.cme.speed >= State.rules.fast_cme) then
        table.insert(run.report, "NASA DONKI: The Sun threw a plasma cloud (CME) at " .. weather.cme.speed .. " km/s! Expected on " .. State.month_day(weather.cme.arrival) .. ".");
    end

    if (weather.particles) then
        table.insert(run.report, "NASA DONKI: Fast particles from the Sun are arriving!");
    end

    if (weather.kp) then
        table.insert(run.report, "NASA DONKI: Storm strength Kp " .. math.floor(weather.kp + 0.5) .. " out of 9.");
    end

    if (dangerous and dose > 0) then
        State.change("radiation", dose);
        table.insert(run.report, "Extra radiation from the Sun: +" .. dose .. ".");
    elseif (dangerous) then
        table.insert(run.report, "The titanium walls blocked the Sun's radiation.");
    end

    return blackout;
end

function State.in_storm()
    local day, storm = State.run.day, State.rules.storm;
    return day >= storm.day and day < storm.day + storm.length;
end

function State.radiation_level()
    local levels, radiation = State.radiation_levels, State.run.radiation;

    for i = #levels, 1, -1 do
        if (radiation >= levels[i].from) then
            return levels[i];
        end
    end
end

function State.amount(effect)
    if (effect.resource == "health" and effect.amount < 0) then
        return math.floor(effect.amount * State.radiation_level().multiplier);
    end

    return effect.amount;
end

function State.can_harvest()
    local run = State.run;
    return run.greenhouse > 0 and run.harvested ~= run.day;
end

function State.blocked(card)
    local power = State.run.power;

    if (card.cost > power) then
        return "Not enough power!";
    end
end

function State.rates()
    local run, rules = State.run, State.rules;
    local solar = (State.in_storm() and 0) or run.panels * rules.panel_power;
    local food, sickness = run.greenhouse * rules.greenhouse_health, State.radiation_level().damage;

    return {
        food = food,
        solar = solar,
        sickness = sickness,
        health = food - rules.hunger - sickness,
        power = solar - rules.life_support_power,
        radiation = State.materials[run.material].radiation
    };
end

---------- { game } ----------

function State.transition(callback)
    local screen = State.screen;

    if (screen.fading) then
        return;
    end

    screen.fading = true;

    flux.to(screen, 1, {
        fade = 1
    }):ease("quadout"):oncomplete(function()
        callback();

        flux.to(screen, 1.5, {
            fade = 0
        }):ease("quadin"):oncomplete(function()
            screen.fading = false;
        end);
    end);
end

function State.next_day()
    State.transition(State.end_day);
end

function State.harvest()
    local run, amount = State.run, State.rules.harvest_health;

    run.harvested = run.day;
    State.change("health", amount);
    table.insert(run.report, "Harvested the greenhouse: health +" .. amount .. ".");
end

function State.start()
    State.run = {
        day = 1,
        power = 12,
        panels = 2,
        material = 1,
        health = 100,
        radiation = 0,
        schedule = {},
        greenhouse = 0,
        upgrade_day = love.math.random(unpack(State.rules.upgrade_every)),
        report = {"Objective: Survive until " .. State.month_day(State.date("%Y-%m-%d", State.rules.days + 1)) .. "! A giant solar storm is coming and only titanium walls can stop it. NASA will warn you when it's close.", "Walk with WASD or the arrow keys. Go to the base and press E to end the day."}
    };

    report_space_weather();
    fire_event("start");
end

function State.change(resource, amount)
    local run, limit = State.run, State.limits[resource];

    if (not limit) then
        error(string.format("[state.lua] Unknown resource: %s", tostring(resource)));
    end

    local old = run[resource];
    run[resource] = math.max(limit[1], math.min(limit[2], old + amount));

    if (run[resource] ~= old) then
        fire_event("change", resource, run[resource] - old);
    end
end

function State.deal(power)
    local run, pool, choices = State.run, {}, {};

    for _, definition in next, State.cards do
        if (definition.upgrade == run.material + 1 and run.day >= run.upgrade_day) then
            choices[1] = definition;
        elseif (not definition.upgrade) then
            table.insert(pool, definition);
        end
    end

    for i = #choices + 1, (love.math.random() < 0.6) and 2 or 3 do
        choices[i] = table.remove(pool, love.math.random(#pool));
    end

    for _, definition in next, choices do
        if (definition.cost <= power) then
            return choices;
        end
    end

    for _, definition in next, pool do
        if (definition.cost == 0) then
            choices[#choices] = definition;
            break;
        end
    end

    return choices;
end

function State.pick(card)
    local run = State.run;

    run.last_pick = card;
    State.change("power", -card.cost);

    if (card.upgrade) then
        run.upgrade_day = run.day + love.math.random(unpack(State.rules.upgrade_every));
    end

    for _, effect in next, card.effects do
        if (effect.delay) then
            State.after(effect.delay, function()
                State.change(effect.resource, State.amount(effect));
                table.insert(run.report, card.name .. " paid off!");
            end);
        else
            State.change(effect.resource, State.amount(effect));
        end
    end
end

function State.end_day()
    local run, rules, rates = State.run, State.rules, State.rates();
    local food, sickness, dose = rates.food, rates.sickness, rates.radiation;

    if (State.in_storm()) then
        run.report = {"Solar storm! The solar panels made no power."};
    else
        run.report = {"Solar panels made +" .. rates.solar .. " power."};
        State.change("power", rates.solar);
    end

    if (run.power >= rules.life_support_power) then
        State.change("power", -rules.life_support_power);
        table.insert(run.report, "Life support used " .. rules.life_support_power .. " power.");
    else
        State.change("power", -run.power);
        State.change("health", -rules.no_power_damage);
        table.insert(run.report, "Not enough power for life support! Crew health -" .. rules.no_power_damage .. ".");
    end

    State.change("health", food - rules.hunger);
    table.insert(run.report, "The crew ate: health -" .. rules.hunger .. ".");

    if (food > 0) then
        table.insert(run.report, "Greenhouse food: health +" .. food .. ".");
    end

    if (sickness > 0) then
        State.change("health", -sickness);
        table.insert(run.report, "High radiation made the crew sick: health -" .. sickness .. ".");
    end

    if (dose > 0) then
        State.change("radiation", dose);
        table.insert(run.report, "Radiation got through the walls: +" .. dose .. ".");
    else
        table.insert(run.report, "The titanium walls blocked all radiation.");
    end

    run.day = run.day + 1;

    for _, callback in next, run.schedule[run.day] or {} do
        callback();
    end

    local status_lines = #run.report;
    local blackout = report_space_weather();
    local days_left, warning = rules.storm.day - run.day, rules.storm.warning;

    if (blackout) then
        run.report[love.math.random(status_lines)] = "~ Radio blackout: this message was lost in static ~";
    end

    if (days_left > 0 and run.day == warning) then
        table.insert(run.report, "ALERT: That plasma cloud is a giant storm! It hits in " .. days_left .. " days. Only titanium walls can stop it!");
    elseif (days_left > 1 and run.day > warning) then
        table.insert(run.report, "Solar storm in " .. days_left .. " days!");
    elseif (days_left == 1) then
        table.insert(run.report, "Solar storm TOMORROW!");
    elseif (days_left == 0) then
        table.insert(run.report, "The solar storm is here! No solar power for " .. rules.storm.length .. " days.");
    end

    run.schedule[run.day] = nil;
    run.over = (run.health <= 0 and "health") or (run.radiation >= 100 and "radiation") or (days_left == 0 and run.material < #State.materials and "storm") or (run.day > rules.days and "win") or nil;
    run.day = math.min(run.day, rules.days);

    fire_event(run.over and "over" or "day");
end

return State;
