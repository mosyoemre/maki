---------- { imports } ----------

local anim8 = require("libraries.anim8");
local flux = require("libraries.flux");
local Prompt = require("modules.prompt");

---------- { variables } ----------

local World, Colors = {}, State.colors;
local ground_y, base_scale = 800, 3;
local base, greenhouse, astronaut, smoke_frames;

---------- { building } ----------

local Building = {}; do
    function Building.new(properties)
        return {
            x = properties.x,
            width = properties.width,
            door = properties.door,
            parts = properties.parts,
            image = properties.image,
            part_count = 0,
            scale = properties.scale or 0,
            door_scale = properties.door_scale,
            part_spots = properties.part_spots,
            bottom = properties.image:getHeight(),

            puff = function(self, x, y, width)
                self.smoke = anim8.newAnimation(smoke_frames, 0.06, "pauseAtEnd");
                self.smoke_x, self.smoke_y, self.smoke_scale = x, y, width / 77;
            end,

            build = function(self, scale)
                self.first_scale = self.first_scale or scale;
                self:puff(self.x, ground_y, self.width * scale);

                flux.to(self, 0.6, {
                    scale = scale
                }):ease("backout");
            end,

            set_parts = function(self, count)
                local spot, part = self.part_spots[count], self.parts;

                if (count > self.part_count) then
                    self:puff(self.x + (spot[1] + part:getWidth() / 2 - self.image:getWidth() / 2) * self.scale, ground_y + (spot[2] + part:getHeight() - self.bottom) * self.scale, part:getWidth() * self.scale);
                end

                self.part_count = count;
            end,

            update = function(self, dt)
                if (self.smoke) then
                    self.smoke:update(dt);

                    if (self.smoke.status == "paused") then
                        self.smoke = nil;
                    end
                end
            end,

            draw = function(self)
                love.graphics.draw(self.image, self.x, ground_y, 0, self.scale, self.scale, self.image:getWidth() / 2, self.bottom);

                for i = 1, self.part_count do
                    local spot = self.part_spots[i];
                    love.graphics.draw(self.parts, self.x, ground_y, 0, self.scale, self.scale, self.image:getWidth() / 2 - spot[1], self.bottom - spot[2]);
                end

                if (self.door) then
                    local scale = self.door_scale * math.min(self.scale / (self.first_scale or 1), 1);
                    love.graphics.draw(self.door, self.x, ground_y, 0, scale, scale, self.door:getWidth() / 2, self.door:getHeight());
                end

                if (self.smoke) then
                    self.smoke:draw(images.smoke, self.smoke_x, self.smoke_y, 0, self.smoke_scale, self.smoke_scale, 138, 135);
                end
            end
        };
    end
end

---------- { astronaut } ----------

local Astronaut = {}; do
    function Astronaut.new(properties)
        local grid = anim8.newGrid(32, 48, images.astronaut:getDimensions());

        local function pose(first)
            return {
                idle = anim8.newAnimation(grid(first, 1), 1),
                walk = anim8.newAnimation(grid((first + 1) .. "-" .. (first + 3), 1), 0.15)
            };
        end

        local poses = {
            right = pose(1),
            front = pose(5),
            left = pose(9),
            back = pose(13)
        };

        return {
            x = properties.x,
            y = properties.y,
            facing = "front",
            animation = poses.front.idle,

            update = function(self, dt)
                local dx = (love.keyboard.isDown("d", "right") and 1 or 0) - (love.keyboard.isDown("a", "left") and 1 or 0);
                local dy = (love.keyboard.isDown("s", "down") and 1 or 0) - (love.keyboard.isDown("w", "up") and 1 or 0);

                if (State.scene ~= "base" or (dx == 0 and dy == 0)) then
                    self.animation = poses[self.facing].idle;
                    return;
                end

                local step = 280 * dt / math.sqrt(dx * dx + dy * dy);
                self.facing = (dx > 0 and "right") or (dx < 0 and "left") or (dy < 0 and "back") or "front";

                local walk = poses[self.facing].walk;

                if (self.animation ~= walk) then
                    walk:gotoFrame(1);
                end

                self.x = math.max(60, math.min(1860, self.x + dx * step));
                self.y = math.max(840, math.min(975, self.y + dy * step));
                self.animation = walk;
                self.animation:update(dt);
            end,

            draw = function(self)
                self.animation:draw(images.astronaut, math.floor(self.x), math.floor(self.y), 0, 4, 4, 16, 48);
            end
        };
    end
end

---------- { main } ----------

local function update_base_material()
    base.image = images.base[State.materials[State.run.material].image];
end

function World.load()
    smoke_frames = anim8.newGrid(256, 256, images.smoke:getDimensions())("1-11", 1);
    astronaut = Astronaut.new {
        x = 960,
        y = 900
    };

    base = Building.new {
        x = 330,
        width = 143,
        image = images.base.plain,
        parts = images.solar_panel,
        scale = base_scale,
        part_spots = {{12, 5}, {52, 12}, {92, 19}, {12, 26}, {52, 33}, {92, 40}}
    };

    greenhouse = Building.new {
        x = 1115,
        width = 216,
        image = images.greenhouse,
        door = images.greenhouse_door,
        door_scale = 4.25
    };

    Prompt.new {
        x = 240,
        y = 900,
        key = "e",
        range = 100,
        name = "Sleep",
        callback = State.next_day
    };

    Prompt.new {
        x = 1115,
        y = 900,
        key = "e",
        range = 150,
        name = "Harvest",
        callback = State.harvest,
        available = State.can_harvest
    };

    State.on("start", function()
        greenhouse.scale, base.part_count = 0, State.run.panels;
        update_base_material();
    end);

    State.on("change", function(resource, amount)
        if (resource == "material") then
            update_base_material();
        end

        if (resource == "greenhouse") then
            greenhouse:build(({2, 3, 4})[State.run.greenhouse] or 0);
        elseif (resource == "panels") then
            base:set_parts(State.run.panels);
        elseif (resource == "material" and amount > 0) then
            base:build(base_scale);
        end
    end);
end

function World.update(dt)
    astronaut:update(dt);
    base:update(dt);
    greenhouse:update(dt);
    Prompt.update(astronaut.x, astronaut.y, State.scene == "base");
end

function World.draw()
    love.graphics.setColor(Colors.secondary);
    love.graphics.draw(images.background, 0, State.screen.height - images.background:getHeight());
    base:draw();
    greenhouse:draw();
    astronaut:draw();
    Prompt.draw(astronaut.x, astronaut.y - 175);
end

return World;