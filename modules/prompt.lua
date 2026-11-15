---------- { imports } ----------

local UI = require("modules.UI");

---------- { variables } ----------

local Prompt, Colors = {}, State.colors;
local prompts, active = {}, nil;
local padding, gap = 14, 16;

---------- { main } ----------

function Prompt.new(properties)
    local prompt = {
        x = properties.x,
        y = properties.y,
        range = properties.range,
        key = properties.key,
        name = properties.name,
        callback = properties.callback,
        available = properties.available
    };

    table.insert(prompts, prompt);
    return prompt;
end

function Prompt.update(x, y, enabled)
    local closest = math.huge;
    active = nil;

    if (not enabled) then
        return;
    end

    for _, prompt in next, prompts do
        local distance = math.sqrt((prompt.x - x) ^ 2 + (prompt.y - y) ^ 2);

        if ((not prompt.available or prompt.available()) and distance <= prompt.range and distance < closest) then
            active, closest = prompt, distance;
        end
    end
end

function Prompt.keypressed(key)
    if (active and key == active.key) then
        active.callback();
    end
end

function Prompt.draw(x, y)
    if (not active) then
        return;
    end

    local font, key = fonts.ui, active.key:upper();
    local key_size = math.max(font:getWidth(key) + padding, font:getHeight());
    local width = padding * 2 + key_size + gap + font:getWidth(active.name);
    local height = key_size + padding * 2;
    local left, top = math.floor(x - width / 2), math.floor(y - height);

    UI.Panel.draw(left, top, width, height, 0.85);
    love.graphics.setColor(Colors.secondary);
    love.graphics.setLineWidth(3);
    love.graphics.rectangle("line", left + padding, top + padding, key_size, key_size);
    love.graphics.setFont(font);
    love.graphics.printf(key, left + padding, top + padding + (key_size - font:getHeight()) / 2, key_size, "center");
    love.graphics.print(active.name, left + padding + key_size + gap, top + padding + (key_size - font:getHeight()) / 2);
end

return Prompt;
