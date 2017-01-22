/**
 * Copyright: Copyright 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop/blob/master/LICENSE, MIT License)
 */
module coop.model.config;

class Config {
    this(string file)
    {
        import std.file;
        import std.path;

        configFile = file;
        if (file.exists)
        {
            import vibe.data.json;
            import std.exception;

            import coop.util;

            auto json = file.readText.parseJsonString;
            enforce(json.type == Json.Type.object);
            windowWidth = json["initWindowWidth"].get!uint;
            windowHeight = json["initWindowHeight"].get!uint;
        }
        else
        {
            // デフォルト値を設定
            windowWidth = 400;
            windowHeight = 300;
        }
    }

    auto save()
    {
        import std.file;
        import std.path;
        import std.stdio;

        mkdirRecurse(configFile.dirName);
        auto f = File(configFile, "w");
        f.write(toJSON);
    }

    auto toJSON()
    {
        import vibe.data.json;
        auto json = Json([ "initWindowWidth": Json(windowWidth),
                           "initWindowHeight": Json(windowHeight),
                             ]);
        return json.serializeToPrettyJson;
    }
    uint windowWidth, windowHeight;
private:
    string configFile;
}
