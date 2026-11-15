---------- { pre-init } ----------

love.graphics.setDefaultFilter("nearest", "nearest");
love.filesystem.setRequirePath("?.lua;?/init.lua;libraries/?.lua;libraries/?/init.lua");

---------- { imports } ----------

State = require("modules.state");

local API = require("modules.api");
local Prompt = require("modules.prompt");
local flux = require("libraries.flux");
local suit = require("libraries.suit");
local World = require("modules.world");
local UI = require("modules.UI");

---------- { variables&helpers } ----------

local Colors, Hand, Hud, Menu, Pause, Report, Cinematic = State.colors, UI.Hand, UI.Hud, UI.Menu, UI.Pause, UI.Report, UI.Cinematic;
local font_path, canvas = "assets/Departure/Regular.otf";

local function font_list(...)
    local sizes, list = {...}, {};

    for i = 1, #sizes do
        list[i] = love.graphics.newFont(font_path, sizes[i]);
    end

    return list;
end

local function to_game(x, y)
    local screen = State.screen;
    return (x - screen.offset_x) / screen.scale, (y - screen.offset_y) / screen.scale;
end

---------- { main } ----------

function love.load()
    fonts = {
        small = love.graphics.newFont(font_path, 24),
        ui = love.graphics.newFont(font_path, 32),
        big = love.graphics.newFont(font_path, 48),
        huge = love.graphics.newFont(font_path, 72),
        title = love.graphics.newFont(font_path, 132),
        card_name = font_list(32, 26, 22, 18),
        card_description = love.graphics.newFont(font_path, 26),
        card_stats = font_list(32, 26, 22, 18)
    };

    images = {
        card_frame = {
            default = love.graphics.newImage("assets/card_frame.png"),
            hover = love.graphics.newImage("assets/card_frame_hover.png"),
            activated = love.graphics.newImage("assets/card_frame_activated.png")
        },
        icons = {
            power = love.graphics.newImage("assets/icons/energy_icon.png"),
            health = love.graphics.newImage("assets/icons/health_icon.png"),
            material = love.graphics.newImage("assets/icons/shield_icon.png"),
            radiation = love.graphics.newImage("assets/icons/radiation_icon.png")
        },
        astronaut = love.graphics.newImage("assets/spritesheets/astronaut_spr.png"),
        background = love.graphics.newImage("assets/bg_main.png"),
        cinematic = love.graphics.newImage("assets/cinematic.png"),
        cinematic_cloud = love.graphics.newImage("assets/cinematic_sand_cloud.png"),
        base = {
            plain = love.graphics.newImage("assets/buildings/base.png"),
            iron = love.graphics.newImage("assets/buildings/base_iron.png"),
            titanium = love.graphics.newImage("assets/buildings/base_titanium.png"),
            aluminium = love.graphics.newImage("assets/buildings/base_aluminium.png")
        },
        greenhouse = love.graphics.newImage("assets/buildings/greenhouse.png"),
        greenhouse_door = love.graphics.newImage("assets/buildings/greenhouse_door.png"),
        solar_panel = love.graphics.newImage("assets/buildings/solar_panel.png"),
        smoke = love.graphics.newImage("assets/spritesheets/smoke_spr.png"),
        card_icons = {}
    };

    for _, card in next, State.cards do
        images.card_icons[card.icon] = love.graphics.newImage("assets/icons/"..card.icon..".png");
    end

    suit.theme.cornerRadius = 0; -- hell yeah
    suit.theme.color = {
        normal = {
            bg = Colors.black,
            fg = Colors.secondary
        },
        active = {
            bg = Colors.primary,
            fg = Colors.secondary
        },
        hovered = {
            bg = Colors.primary_dark,
            fg = Colors.secondary
        }
    };

    canvas = love.graphics.newCanvas(State.screen.width, State.screen.height);
    canvas:setFilter("linear", "linear");
    love.resize(love.graphics.getDimensions());
    State.load_space_weather();
    World.load();
    Menu.load();
end

function love.resize(width, height)
    local screen = State.screen;

    screen.scale = math.min(width / screen.width, height / screen.height);
    screen.offset_x = math.floor((width - screen.width * screen.scale) / 2);
    screen.offset_y = math.floor((height - screen.height * screen.scale) / 2);
end

function love.update(dt)
    local mx, my = to_game(love.mouse.getPosition());
    local mouse_down = love.mouse.isDown(1);

    API.update();
    suit.updateMouse(mx, my, mouse_down);
    love.graphics.setFont(fonts.ui);

    if (State.paused) then
        Pause.update();
        return;
    end

    flux.update(dt);

    if (State.scene == "menu") then
        Menu.update();
    elseif (State.scene ~= "cinematic") then
        World.update(dt);
        Hud.update();
        Hand.update(mx, my, mouse_down);
    end
end

function love.keypressed(key)
    if (key == "escape" or key == "p") then
        Pause.toggle();
        return;
    end

    if (State.paused) then
        return;
    end

    Cinematic.skip();
    Report.skip();
    Prompt.keypressed(key);
end

function love.mousepressed(x, y, button)
    if (State.paused) then
        return;
    end

    Cinematic.skip();
    Report.skip();

    if (button == 1) then
        Hand.mousepressed(to_game(x, y));
    end
end

function love.mousereleased(x, y, button)
    if (button == 1 and not State.paused) then
        Hand.mousereleased(to_game(x, y));
    end
end

function love.draw()
    local screen = State.screen;

    love.graphics.setCanvas(canvas);
    love.graphics.clear();

    if (State.scene == "menu") then
        Menu.draw();
    elseif (State.scene == "cinematic") then
        Cinematic.draw();
    else
        World.draw();
        Hand.draw();
        Hud.draw();
    end

    if (State.paused) then
        Pause.draw();
    end

    suit.draw();
    love.graphics.setColor(Colors.to_tuple(Colors.black, screen.fade));
    love.graphics.rectangle("fill", 0, 0, screen.width, screen.height);
    love.graphics.setCanvas();
    love.graphics.setColor(Colors.secondary);
    love.graphics.draw(canvas, screen.offset_x, screen.offset_y, 0, screen.scale, screen.scale);
end
