function love.conf(t)
    t.version = "11.4";
    t.identity = "maki";
    
    t.window.width = 1280;
    t.window.height = 720;
    t.window.title = "MAKI";
    t.window.icon = "assets/logo.png";
    t.window.minwidth = 640;
    t.window.minheight = 360;
    t.window.resizable = true;

    t.modules.physics = false;
    t.modules.joystick = false;
end
