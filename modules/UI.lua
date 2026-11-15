local flux = require("libraries.flux");
local suit = require("libraries.suit");

local Colors = State.colors;

local Text = {}; do
    function Text.fit(font_list, text, max_width)
        for i = 1, #font_list do
            if (font_list[i]:getWidth(text) <= max_width) then
                return font_list[i];
            end
        end

        return font_list[#font_list];
    end

    function Text.print_in_box(text, font, box, align)
        love.graphics.setFont(font);
        love.graphics.printf(text, box.x, math.floor(box.y + (box.height - font:getHeight()) / 2), box.width, align);
    end

    function Text.print_centered(text, font, y, color)
        love.graphics.setColor(color or Colors.secondary);
        love.graphics.setFont(font);
        love.graphics.printf(text, 0, y, State.screen.width, "center");
    end
end

local Panel = {}; do
    function Panel.draw(x, y, width, height, alpha, heading)
        love.graphics.setColor(Colors.to_tuple(Colors.dark, alpha));
        love.graphics.rectangle("fill", x, y, width, height);

        if (heading) then
            love.graphics.setColor(Colors.secondary);
            love.graphics.setFont(fonts.huge);
            love.graphics.printf(heading, x, y + 40, width, "center");
        end
    end
end

local Icon = {
    gear = {"    ###    ", " ## ### ## ", " ######### ", "  #######  ", "####   ####", "####   ####", "####   ####", "  #######  ", " ######### ", " ## ### ## ", "    ###    "}
}; do
    function Icon.draw(name, x, y, pixel)
        local pattern = Icon[name];
        local left, top = x - #pattern[1] * pixel / 2, y - #pattern * pixel / 2;

        for row = 1, #pattern do
            for column = 1, #pattern[row] do
                if (pattern[row]:sub(column, column) == "#") then
                    love.graphics.rectangle("fill", left + (column - 1) * pixel, top + (row - 1) * pixel, pixel, pixel);
                end
            end
        end
    end
end

local Card = {}; do
    Card.pixel_scale = 6;
    Card.width = 64 * Card.pixel_scale;
    Card.height = 96 * Card.pixel_scale;

    local function region(x, y, width, height)
        local scale = Card.pixel_scale;
        
        return {
            x = x * scale - Card.width / 2,
            y = y * scale - Card.height / 2,
            width = width * scale,
            height = height * scale
        };
    end

    local regions = {
        name = region(9, 46, 46, 9),
        stats = region(9, 79, 46, 9),
        art = region(14, 12, 36, 32),
        description = region(9, 56, 46, 31),
    };

    local labels = {
        power = "PWR",
        health = "HP",
        panels = "PANEL",
        material = "BASE",
        radiation = "RAD",
        greenhouse = "GREENH"
    };

    local function build_stats(effects)
        local colored, str = {}, "";

        for i = 1, #effects do
            local effect, amount = effects[i], State.amount(effects[i]);
            local text = (i > 1 and "  " or "")..(amount >= 0 and "+" or "")..amount.." "..labels[effect.resource]..(effect.delay and " @"..(State.run.day + effect.delay) or "");

            table.insert(colored, ((amount >= 0) ~= (effect.resource == "radiation")) and Colors.food or Colors.danger);
            table.insert(colored, text);

            str = str..text;
        end

        return colored, str;
    end

    function Card.new(properties)
        local stats_colored, stats_plain = build_stats(properties.definition.effects);

        return {
            definition = properties.definition,
            x = properties.x,
            y = properties.y,
            lift = 0,
            scale = 1,
            alpha = 0,
            state = "default",
            disabled = properties.disabled,
            stats_colored = stats_colored,
            stats_plain = stats_plain,

            contains = function(self, x, y)
                return math.abs(x - self.x) <= Card.width * self.scale / 2 and math.abs(y - self.y - self.lift) <= Card.height * self.scale / 2;
            end,

            set_hover = function(self, hovered, pressed)
                local state = hovered and (pressed and "activated" or "hover") or "default";
                local raised = state ~= "default";

                if (raised ~= (self.state ~= "default")) then
                    if (self.hover_tween) then
                        self.hover_tween:stop();
                    end

                    self.hover_tween = flux.to(self, 0.15, {
                        lift = raised and -40 or 0,
                        scale = raised and 1.06 or 1
                    }):ease("quadout");
                end

                self.state = state;
            end,

            draw = function(self)
                local definition = self.definition;
                local dim = self.disabled and 0.55 or 1;
                local cost = tostring(definition.cost);

                love.graphics.push("all");
                love.graphics.translate(math.floor(self.x + 0.5), math.floor(self.y + self.lift + 0.5));
                love.graphics.scale(self.scale);

                love.graphics.setColor(Colors.to_tuple(Colors.secondary, self.alpha, dim));
                love.graphics.draw(images.card_frame[self.state], -Card.width / 2, -Card.height / 2, 0, Card.pixel_scale, Card.pixel_scale);

                local art, icon = regions.art, images.card_icons[definition.icon];

                love.graphics.setColor(Colors.to_tuple(Colors[definition.type], self.alpha * 0.35, dim));
                love.graphics.rectangle("fill", art.x, art.y, art.width, art.height);
                love.graphics.setColor(Colors.to_tuple(Colors.secondary, self.alpha, dim));
                love.graphics.draw(icon, art.x + (art.width - icon:getWidth() * Card.pixel_scale) / 2, art.y + (art.height - icon:getHeight() * Card.pixel_scale) / 2, 0, Card.pixel_scale, Card.pixel_scale);

                local name = string.format("%s (%s)", definition.name, cost);
                love.graphics.setColor(Colors.to_tuple(Colors.primary, self.alpha, dim));
                Text.print_in_box(name, Text.fit(fonts.card_name, name, regions.name.width), regions.name, "center");
                
                love.graphics.setColor(Colors.to_tuple(Colors.secondary, self.alpha, dim));
                Text.print_in_box(self.stats_colored, Text.fit(fonts.card_stats, self.stats_plain, regions.stats.width), regions.stats, "center");
                love.graphics.setFont(fonts.card_description);
                love.graphics.printf(definition.description, regions.description.x, regions.description.y, regions.description.width, "center");
                
                love.graphics.pop();
            end
        };
    end
end

local Hand = {}; do
    local function card_under(x, y)
        local cards = State.hand.cards;

        for i = #cards, 1, -1 do
            if (cards[i]:contains(x, y)) then
                return i;
            end
        end
    end

    local function can_interact()
        return State.scene == "decide" and not State.hand.picking;
    end

    local function draw_warning(text, x, bottom)
        local font = fonts.small;
        local width, height = font:getWidth(text) + 32, font:getHeight() + 24;
        local left, top = math.floor(x - width / 2), math.floor(bottom - height);

        Panel.draw(left, top, width, height, 0.9);
        love.graphics.setColor(Colors.danger);
        love.graphics.setLineWidth(3);
        love.graphics.rectangle("line", left, top, width, height);
        love.graphics.setColor(Colors.secondary);
        love.graphics.setFont(font);
        love.graphics.print(text, left + 16, top + 12);
    end

    local function pick(index)
        local hand = State.hand;
        local chosen = hand.cards[index];

        hand.picking = true;

        for i = 1, #hand.cards do
            if (i ~= index) then
                flux.to(hand.cards[i], 0.25, {
                    alpha = 0,
                    y = hand.cards[i].y + 120
                });
            end
        end

        flux.to(chosen, 0.25, {
            scale = 1.15
        }):ease("quadout"):after(chosen, 0.3, {
            alpha = 0,
            y = chosen.y - 200
        }):ease("quadin"):oncomplete(function()
            State.pick(chosen.definition);
            State.scene = "base";

            flux.to(hand, 0.3, {
                shade = 0
            });
        end);
    end

    function Hand.open()
        local hand, power = State.hand, State.run.power;
        local choices, gap, row_y = State.deal(power), 64, 585;
        local step = Card.width + gap;
        local first_x = (State.screen.width - #choices * step + gap + Card.width) / 2;

        hand.cards, hand.picking, hand.hovered_index = {}, false, nil;
        State.scene = "decide";

        for i = 1, #choices do
            hand.cards[i] = Card.new {
                y = row_y + 700,
                definition = choices[i],
                x = first_x + (i - 1) * step,
                disabled = State.blocked(choices[i])
            };

            flux.to(hand.cards[i], 0.4, {
                alpha = 1,
                y = row_y
            }):ease("backout"):delay((i - 1) * 0.08);
        end

        flux.to(hand, 0.3, {
            shade = 0.6
        });
    end

    function Hand.update(x, y, mouse_down)
        if (not can_interact()) then
            return;
        end

        local hand = State.hand;
        hand.hovered_index = card_under(x, y);

        for i = 1, #hand.cards do
            hand.cards[i]:set_hover(i == hand.hovered_index and not hand.cards[i].disabled, mouse_down);
        end
    end

    function Hand.mousepressed(x, y)
        if (can_interact()) then
            State.hand.pressed_index = card_under(x, y);
        end
    end

    function Hand.mousereleased(x, y)
        local hand, index = State.hand, card_under(x, y);
        local pressed_index = hand.pressed_index;

        hand.pressed_index = nil;

        if (can_interact() and index and index == pressed_index and not hand.cards[index].disabled) then
            pick(index);
        end
    end

    function Hand.draw()
        local hand, screen = State.hand, State.screen;

        Panel.draw(0, 0, screen.width, screen.view_height, hand.shade);

        if (State.scene ~= "decide") then
            return;
        end

        Text.print_centered("Choose one for today", fonts.big, 140);

        for i = 1, #hand.cards do
            if (i ~= hand.hovered_index) then
                hand.cards[i]:draw();
            end
        end

        local card = hand.cards[hand.hovered_index];

        if (card) then
            card:draw();
        end

        if (card and card.disabled) then
            draw_warning(card.disabled, card.x, card.y + card.lift - Card.height * card.scale / 2 - 16);
        end
    end
end

local Report = {}; do
    local report = {
        progress = 1
    };

    local function shrink(delay)
        if (report.tween) then
            report.tween:stop();
        end

        report.tween = flux.to(report, 0.6, {
            progress = 1
        }):ease("quadinout"):delay(delay):oncomplete(function()
            report.tween = nil;
            Hand.open();
        end);
    end

    function Report.open()
        State.scene, report.progress = "report", 0;
        shrink(4);
    end

    State.on("start", Report.open);
    State.on("day", Report.open);

    function Report.skip()
        if (State.scene == "report" and report.progress == 0) then
            shrink(0);
        end
    end

    function Report.cancel()
        if (report.tween) then
            report.tween:stop();
            report.tween = nil;
        end
    end

    function Report.draw()
        local screen, run = State.screen, State.run;
        local progress, collapsed = report.progress, report.progress == 1 and not love.keyboard.isDown("tab");
        local text, today = table.concat(run.report, "\n"), (State.scene == "base" and "\nToday: "..run.last_pick.name) or "";

        if (collapsed) then
            text, today = "Hold TAB to expand", "";
        end

        local width = (collapsed and fonts.small:getWidth(text) + 40) or 630;
        local _, rows = fonts.small:getWrap(text..today, width - 40);
        local height = #rows * fonts.small:getHeight() + 20;
        local center_x = screen.width / 2 + (screen.width / 2 - 20 - width / 2) * progress;
        local center_y = screen.view_height / 2 + (20 + height / 2 - screen.view_height / 2) * progress;

        love.graphics.push();
        love.graphics.translate(math.floor(center_x), math.floor(center_y));
        love.graphics.scale(2 - progress);

        Panel.draw(-width / 2, -height / 2, width, height, 0.85 - 0.4 * progress);
        love.graphics.setColor(Colors.secondary);
        love.graphics.setFont(fonts.small);
        love.graphics.printf({Colors.secondary, text, Colors.power, today}, 20 - width / 2, 10 - height / 2, width - 40, "left");

        love.graphics.pop();
    end
end

local ResourceBar = {}; do
    local icon_size, meter_width = 64, 220;
    local items = {"power", "health", "radiation", "material"};

    function ResourceBar.draw()
        local screen, run, rates = State.screen, State.run, State.rates();
        local height = screen.height - screen.view_height;
        local center_y = screen.view_height + height / 2;
        local value_y = math.floor(center_y - fonts.big:getHeight() / 2) - 8;
        local rate_y = value_y + fonts.big:getHeight() - fonts.small:getHeight() - 6;

        love.graphics.setColor(Colors.dark);
        love.graphics.rectangle("fill", 0, screen.view_height, screen.width, height);

        for i = 1, #items do
            local resource = items[i];
            local x, value, color = (i - 1) * screen.width / #items + 80, run[resource], Colors[resource];
            local icon, max = images.icons[resource], State.limits[resource][2];
            local icon_scale = icon_size / icon:getWidth();

            love.graphics.setColor(Colors.secondary);
            love.graphics.draw(icon, x, math.floor(center_y - icon_size / 2), 0, icon_scale, icon_scale);
            love.graphics.setColor((resource == "radiation" and value > 70) and Colors.danger or color);

            local text, rate = (resource == "material" and State.materials[value].name) or tostring(value), rates[resource];

            love.graphics.setFont(fonts.big);
            love.graphics.print(text, x + 90, value_y);

            if (rate) then
                love.graphics.setColor(rate == 0 and {Colors.to_tuple(Colors.secondary, 0.5)} or ((rate > 0) ~= (resource == "radiation") and Colors.food or Colors.danger));
                love.graphics.setFont(fonts.small);
                love.graphics.print((rate > 0 and "+" or "")..rate .."/day", x + 106 + fonts.big:getWidth(text), rate_y);
            end

            love.graphics.setColor(Colors.to_tuple(Colors.secondary, 0.15));
            love.graphics.rectangle("fill", x + 90, center_y + 22, meter_width, 8);
            love.graphics.setColor(color);
            love.graphics.rectangle("fill", x + 90, center_y + 22, meter_width * value / max, 8);
        end
    end
end

local Cinematic = {}; do
    local finished = false;
    local cinematic = {
        time = 0,
        cloud_x = 0,
        camera_x = 0
    };

    local lines = {{"April 10, 2024 – Your crew lands on Mars", 1.2, 3.8}, {"They went for exploration and suddenly\na sand storm happened...", 4.2, 30}};

    local function finish()
        if (finished or State.screen.fading) then
            return;
        end

        finished = true;
        State.transition(State.start);
    end

    function Cinematic.open()
        State.scene, finished = "cinematic", false;
        cinematic.time, cinematic.cloud_x, cinematic.camera_x = 0, 853, 240;

        flux.to(cinematic, 60, {
            time = 60
        }):ease("linear");

        flux.to(cinematic, 7, {
            camera_x = 0
        }):ease("sineinout");

        flux.to(cinematic, 8, {
            cloud_x = -1300
        }):ease("linear"):delay(1.5):onupdate(function()
            if (cinematic.cloud_x <= -800) then
                finish();
            end
        end);
    end

    function Cinematic.skip()
        if (State.scene == "cinematic") then
            finish();
        end
    end

    function Cinematic.draw()
        local camera_x = math.floor(cinematic.camera_x);

        love.graphics.setColor(Colors.secondary);
        love.graphics.draw(images.cinematic, -camera_x, 0);
        love.graphics.draw(images.cinematic_cloud, math.floor(cinematic.cloud_x) - camera_x, 0);
        love.graphics.setFont(fonts.big);

        for _, line in next, lines do
            local alpha = math.max(0, math.min(1, (cinematic.time - line[2]) / 0.6, (line[3] - cinematic.time) / 0.6));

            love.graphics.setColor(Colors.to_tuple(Colors.secondary, alpha));
            love.graphics.printf(line[1], (State.screen.width - 1400) / 2, 150, 1400, "center");
        end
    end
end

local Menu = {}; do
    local music;
    local tools = {"Tools & Libraries", "LÖVE, SUIT (vrld), flux (rxi), anim8 (kikito)\nlunajson (grafi-tt), Departure Mono (Helena Zhang)"};
    local team = {{"Software", "Onur Emre ATEŞOĞLU"}, {"Audio Engineer", "Akın PEHLİVAN"}, {"Art", "Kuzey BALDİL\nKerem DURAN"}, {"Researcher", "Çilek Defne ÇIRAK"}};

    function Menu.load()
        if (love.filesystem.getInfo("assets/theme.wav")) then
            music = love.audio.newSource("assets/theme.wav", "stream");
            music:setLooping(true);
            music:play();
        end
    end

    local function toggle_music()
        State.menu.music = not State.menu.music;

        if (music) then
            (State.menu.music and music.play or music.pause)(music);
        end
    end

    local function draw_icon_button(text, options, x, y, width, height)
        suit.theme.Button(text, options, x, y, width, height);
        love.graphics.setColor(Colors.secondary);
        Icon.draw(options.icon, x + width / 2, y + height / 2, 8);
    end

    local function start_game()
        local menu = State.menu;
        menu.page = "scrolling";

        State.transition(function()
            menu.camera_y = images.background:getHeight() - State.screen.height;
            Cinematic.open();
        end);
    end

    function Menu.open()
        local menu = State.menu;
        State.scene, menu.page = "menu", "scrolling";

        flux.to(menu, 1.4, {
            camera_y = 0
        }):ease("quadinout"):oncomplete(function()
            menu.page = "main";
        end);
    end

    function Menu.update()
        local menu = State.menu;

        if (menu.page == "main") then
            if (suit.Button("▷ PLAY", {
                font = fonts.huge
            }, 590, 780, 560, 140).hit) then
                start_game();
            end

            if (suit.Button("", {
                icon = "gear",
                id = "settings",
                draw = draw_icon_button
            }, 1190, 780, 140, 140).hit) then
                menu.page = "settings";
            end
        elseif (menu.page == "settings") then
            if (suit.Button("MUSIC: "..(menu.music and "ON" or "OFF"), 660, 400, 600, 110).hit) then
                toggle_music();
            end

            if (suit.Button("CREDITS", 660, 540, 600, 110).hit) then
                menu.page = "credits";
            end

            if (suit.Button("BACK", 660, 740, 600, 110).hit) then
                menu.page = "main";
            end
        elseif (menu.page == "credits" and suit.Button("BACK", 760, 880, 400, 100).hit) then
            menu.page = "settings";
        end
    end

    local function draw_credit(section, x, y, width, height)
        local _, rows = fonts.ui:getWrap(section[2], width);
        local top = math.floor(y + (height - fonts.big:getHeight() - #rows * fonts.ui:getHeight()) / 2);

        love.graphics.setColor(Colors.primary);
        love.graphics.setFont(fonts.big);
        love.graphics.printf(section[1], x, top, width, "center");
        love.graphics.setColor(Colors.secondary);
        love.graphics.setFont(fonts.ui);
        love.graphics.printf(section[2], x, top + fonts.big:getHeight(), width, "center");
    end

    function Menu.draw()
        local menu = State.menu;
        local title_alpha = 1 - menu.camera_y / 200;

        love.graphics.setColor(Colors.secondary);
        love.graphics.draw(images.background, 0, -menu.camera_y);

        if (menu.page == "settings") then
            Panel.draw(560, 200, 800, 700, 0.8, "SETTINGS");
        elseif (menu.page == "credits") then
            local cell_width, cell_height = 600, 240;
            Panel.draw(360, 100, 1200, 920, 0.8, "CREDITS");

            for i = 1, #team do
                draw_credit(team[i], 360 + (i - 1) % 2 * cell_width, 240 + math.floor((i - 1) / 2) * (cell_height - 75), cell_width, cell_height);
            end

            draw_credit(tools, 360, 160 + 2 * cell_height, cell_width * 2, cell_height * 2 / 3);
        elseif (title_alpha > 0) then
            Text.print_centered("MAKI", fonts.title, 158 - menu.camera_y, {Colors.to_tuple(Colors.dark, 0.6 * title_alpha)});
            Text.print_centered("MAKI", fonts.title, 150 - menu.camera_y, {Colors.to_tuple(Colors.secondary, title_alpha)});

            local status, bottom = State.donki.status, State.screen.height - 20;
            Panel.draw(20, bottom - fonts.small:getHeight() - 20, fonts.small:getWidth(status) + 40, fonts.small:getHeight() + 20, 0.6 * title_alpha);
            love.graphics.setColor(Colors.to_tuple(Colors.secondary, title_alpha));
            love.graphics.setFont(fonts.small);
            love.graphics.print(status, 40, bottom - fonts.small:getHeight() - 10);
        end
    end
end

local Hud = {}; do
    local endings = {
        win = {"MISSION COMPLETE!", "Your titanium base kept the crew safe through the giant solar storm of May 2024!"},
        health = {"THE CREW HAD TO GO HOME", "Their health ran out. The crew eats every day, so build a greenhouse early and harvest it. Try again?"},
        radiation = {"TOO MUCH RADIATION", "Radiation dose never goes down, it only adds up. That's why real bases build strong walls early. Try again?"},
        storm = {"THE STORM WAS TOO STRONG", "Only titanium walls could block a storm this big. In May 2024 the same sunspot also hit Mars, and NASA's Curiosity rover measured the radiation. Try again?"}
    };

    State.on("over", function()
        State.scene = "over";
    end);

    function Hud.update()
        if (State.scene ~= "over") then
            return;
        end

        if (suit.Button("Try Again", 600, 560, 320, 90).hit) then
            State.start();
        end

        if (suit.Button("Main Menu", 1000, 560, 320, 90).hit) then
            Menu.open();
        end
    end

    function Hud.draw()
        local screen, run = State.screen, State.run;
        local day, date = "DAY "..run.day, State.date();

        if (State.scene == "over") then
            local ending, won = endings[run.over], run.over == "win";

            love.graphics.setColor(won and Colors.trophy or Colors.black);
            love.graphics.rectangle("fill", 0, 0, screen.width, screen.height);
            Text.print_centered(ending[1], fonts.huge, 250, won and Colors.black or Colors.secondary);
            love.graphics.setFont(fonts.ui);
            love.graphics.printf(ending[2], 300, 380, screen.width - 600, "center");
        elseif (State.scene == "decide") then
            ResourceBar.draw();
        else
            Panel.draw(20, 20, math.max(fonts.big:getWidth(day), fonts.ui:getWidth(date)) + 40, fonts.big:getHeight() + fonts.ui:getHeight() + 20, 0.45);
            love.graphics.setColor(Colors.secondary);
            love.graphics.setFont(fonts.big);
            love.graphics.print(day, 40, 30);
            love.graphics.setFont(fonts.ui);
            love.graphics.print(date, 40, 30 + fonts.big:getHeight());
            ResourceBar.draw();
            Report.draw();
        end
    end
end

local Pause = {}; do
    local scenes = {
        base = true,
        decide = true,
        report = true
    };

    function Pause.toggle()
        if (State.paused) then
            State.paused = false;
        elseif (scenes[State.scene] and not State.screen.fading and not State.hand.picking) then
            State.paused = true;
        end
    end

    function Pause.update()
        if (suit.Button("RESUME", 660, 400, 600, 110).hit) then
            State.paused = false;
        end

        if (suit.Button("MAIN MENU", 660, 560, 600, 110).hit) then
            State.paused, State.hand.shade = false, 0;
            Report.cancel();
            Menu.open();
        end
    end

    function Pause.draw()
        local screen = State.screen;

        Panel.draw(0, 0, screen.width, screen.height, 0.5);
        Panel.draw(560, 200, 800, 560, 0.8, "PAUSED");
    end
end

return {
    Hud = Hud,
    Card = Card,
    Hand = Hand,
    Icon = Icon,
    Menu = Menu,
    Text = Text,
    Panel = Panel,
    Pause = Pause,
    Report = Report,
    Cinematic = Cinematic,
    ResourceBar = ResourceBar
}; -- god i would love some js syntax over here!
