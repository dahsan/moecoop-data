/**
 * Copyright: Copyright 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop/blob/master/LICENSE, MIT License)
 */
module coop.core;

enum SortOrder {
    BySkill       = "スキル値順",
    ByName        = "名前順",
    ByBinderOrder = "バインダー順",
}

public import coop.core.wisdom: Binder, Category;

class WisdomModel
{
    /// コンストラクタ
    this(Wisdom w) @safe
    {
        wisdom = w;
        migemo = initMigemo;
    }

    /// Migemo 検索が利用可能かどうかを返す
    @property auto migemoAvailable() const @safe pure nothrow @nogc
    {
        return migemo !is null;
    }

    /// バインダー一覧を返す
    @property auto getBinderCategories() const pure nothrow
    {
        return wisdom.binders;
    }

    /// スキル一覧を返す
    @property auto getSkillCategories() const pure nothrow
    {
        return wisdom.recipeCategories;
    }

    /// レシピ情報を返す
    auto getRecipe(Str)(Str name) if (isSomeString!Str)
    {
        import std.conv;
        return wisdom.recipeFor(name.to!string);
    }

    /// アイテム情報を返す
    auto getItem(Str)(Str name) if (isSomeString!Str)
    {
        import std.conv;
        import coop.core.item;

        if (auto i = name.to!string in wisdom.itemList)
        {
            return *i;
        }
        else
        {
            Item item;
            item.petFoodInfo = [PetFoodType.UNKNOWN.to!PetFoodType: 0];
            return item;
        }
        assert(false);
    }

    /// レシピが収録されているバインダーを返す
    auto getBindersFor(Str)(Str name) if (isSomeString!Str)
    {
        import std.conv;
        return wisdom.bindersFor(name.to!string);
    }

    /// アイテムの固有情報を返す
    auto getExtraInfo(Str)(Str name) if (isSomeString!Str)
    {
        import std.conv;
        import std.typecons;
        import coop.core.item;

        alias RetType = Tuple!(ItemType, "type", ExtraInfo, "extra");

        if (auto i = name.to!string in wisdom.itemList)
        {
            if ((*i).type == ItemType.Others)
            {
                RetType ret;
                ret.type = ItemType.Others;
                return ret;
            }
            else if ((*i).type !in wisdom.extraInfoList ||
                     (*i).name !in wisdom.extraInfoList[(*i).type])
            {
                return RetType.init;
            }
            return RetType((*i).type, wisdom.extraInfoList[(*i).type][(*i).name]);
        }
        else
        {
            return RetType.init;
        }
        assert(false);
    }

    /// 飲食物のバフ効果を返す
    auto getFoodEffect(Str)(Str name) if (isSomeString!Str)
    {
        import std.conv;
        if (auto einfo = name.to!string in wisdom.foodEffectList)
        {
            return *einfo;
        }
        else
        {
            import coop.core.item;
            return AdditionalEffect.init;
        }
        assert(false);
    }

    /// binder に収録されているレシピ一覧を返す
    auto getRecipeList(Str)(Str query, Binder binder,
                            Flag!"useMetaSearch" useMetaSearch, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch = No.useReverseSearch)
        if (isSomeString!Str)
    {
        import std.algorithm;
        import std.array;
        import std.conv;
        import std.typecons;

        alias RecipePair = Tuple!(string, "category", string[], "recipes");

        auto allRecipes = useMetaSearch ?
                          wisdom.binderList :
                          [tuple(cast(string)binder, wisdom.recipesIn(binder))].assocArray;
        auto queryResult = getQueryResultBase(query.to!string, allRecipes, useMetaSearch, useMigemo, useReverseSearch);
        return queryResult.byKeyValue.map!((kv) {
                return [RecipePair(kv.key, kv.value.array)];
            }).joiner;
    }

    /// スキルカテゴリ category に分類されているレシピ一覧を返す
    auto getRecipeList(Str)(Str query, Category category,
                            Flag!"useMetaSearch" useMetaSearch, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch,
                            SortOrder order)
        if (isSomeString!Str)
    {
        import std.algorithm;
        import std.array;
        import std.conv;
        import std.typecons;

        alias RecipePair = Tuple!(string, "category", string[], "recipes");

        auto allRecipes = useMetaSearch ?
                          wisdom.skillList.byKeyValue.map!(kv => tuple(kv.key, kv.value.array)).assocArray :
                          [tuple(cast(string)category, wisdom.recipesIn(category).array)].assocArray;
        auto queryResult = getQueryResultBase(query.to!string, allRecipes, useMetaSearch, useMigemo, useReverseSearch);
        return queryResult.byKeyValue.map!((kv) {
                import std.range;
                auto category = kv.key;
                auto rs = kv.value;

                if (rs.empty)
                {
                    return [RecipePair(category, rs.array)];
                }

                final switch(order) with(SortOrder)
                {
                case BySkill:
                    auto levels(string s) {
                        auto arr = wisdom.recipeFor(s).requiredSkills.byKeyValue.map!(a => tuple(a.key, a.value)).array;
                        arr.multiSort!("a[0] < b[0]", "a[1] < b[1]");
                        return arr;
                    }
                    auto lvToStr(Tuple!(string, double)[] tpls)
                    {
                        import std.format;
                        return tpls.map!(t => format("%s (%.1f)", t.tupleof)).join(", ");
                    }
                    auto arr = rs.map!(a => tuple(a, levels(a))).array;
                    arr.multiSort!("a[1] < b[1]", "a[0] < b[0]");
                    return arr.chunkBy!"a[1]"
                              .map!(a => RecipePair(lvToStr(a[0]), a[1].map!"a[0]".array))
                              .array;
                case ByName:
                    return [RecipePair(category, rs.sort().array)];
                case ByBinderOrder:
                    assert(false);
                }
            }).joiner;
    }

    /// query にヒットするレシピ一覧を返す。
    /// Yes.useReverseSearch の場合には、query にヒットするアイテムを材料にするレシピ一覧を返す
    auto getRecipeList(Str)(Str query, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch)
    {
        import std.algorithm;
        import std.range;
        return getRecipeList(query, Category.init, Yes.useMetaSearch, useMigemo, useReverseSearch, SortOrder.ByName).map!"a.recipes".joiner.array;
    }

    /// query にヒットするアイテム一覧を返す
    auto getItemList(Str)(Str query, Flag!"useMigemo" useMigemo, Flag!"canBeProduced" canBeProduced)
        if (isSomeString!Str)
    {
        import std.algorithm;
        import std.array;

        auto items = canBeProduced ?
                     wisdom.rrecipeList.keys :
                     wisdom.itemList.keys;
        auto queryFun = matchFunFor(query, useMigemo);
        return items.filter!queryFun.array;
    }

    /// 
    @property auto getDefaultPreference() const @safe pure nothrow
    {
        import coop.core.recipe_graph;
        return RecipeGraph.defaultPreference;
    }

    /// 
    auto getMenuRecipeResult(Str)(Str[] targets)
        if (isSomeString!Str)
    {
        import std.conv;
        import coop.core.recipe_graph;
        auto graph = new RecipeGraph(targets.to!(string[]), wisdom, null);
        return graph.elements;
    }

    /// 
    auto getMenuRecipeResult(Str1, Str2, Str3, Str4)(int[Str1] targets, int[Str2] owned, Str3[Str3] preference, RedBlackTree!Str4 terminals)
        if (isSomeString!Str1 && isSomeString!Str2 &&
            isSomeString!Str3 && isSomeString!Str4)
    {
        import std.conv;
        import std.range;
        import coop.core.recipe_graph;
        auto graph = new RecipeGraph(targets.keys.to!(string[]), wisdom, preference.to!(string[string]));
        return graph.elements(targets.to!(int[string]), owned.to!(int[string]), new RedBlackTree!string(terminals[].array.to!(string[])));
    }

    ///
    auto costFor(Str)(Str item, int[string] procs)
        if (isSomeString!Str)
    {
        import std.conv;
        import coop.core.price;

        return referenceCostFor(item.to!string,
                                wisdom.itemList, wisdom.recipeList, wisdom.rrecipeList,
                                wisdom.vendorPriceList, (int[string]).init,
                                procs);
    }

private:
    import std.container;
    import std.traits;
    import std.typecons;
    import coop.core.wisdom;
    import coop.migemo;

    auto getQueryResultBase(string query, string[][string] allRecipes,
                            Flag!"useMetaSearch" useMetaSearch, Flag!"useMigemo" useMigemo,
                            Flag!"useReverseSearch" useReverseSearch = No.useReverseSearch)
    {
        import std.algorithm;
        import std.range;
        import std.string;

        auto input = query.removechars(r"/[ 　]/");
        auto queryFun = matchFunFor(query, useMigemo, useReverseSearch);

        return input.empty ?
            allRecipes :
            allRecipes.byKeyValue
                      .map!(kv =>
                            tuple(kv.key,
                                  kv.value.filter!queryFun.array))
                      .filter!"!a[1].empty"
                      .assocArray;
    }

    auto matchFunFor(string query, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch = No.useReverseSearch)
    {
        import std.regex;
        import std.string;
        bool delegate(string) fun;
        if (useMigemo)
        {
            assert(migemo);
            try{
                auto q = migemo.query(query).regex;
                fun = (string s) => !s.removechars(r"/[ 　]/").matchFirst(q).empty;
            } catch(RegexException e) {
                // use default matchFun
            }
        }
        else
        {
            import std.algorithm;
            import std.range;

            fun = (string s) => !find(s.removechars(r"/[ 　]/"), boyerMooreFinder(query)).empty;
        }

        if (useReverseSearch)
        {
            import std.algorithm;
            return (string s) => wisdom.recipeFor(s).ingredients.keys.any!(ing => fun(ing));
        }
        else
        {
            return (string s) => fun(s);
        }
        assert(false);
    }

    static auto initMigemo() @safe
    {
        import std.file;

        auto info = migemoInfo;

        if (info.lib.exists)
        {
            Migemo m;
            try{
                import std.exception;
                import std.path;

                m = new Migemo(info.lib, info.dict);
                m.load(buildPath("resource", "dict", "moe-dict"));
                enforce(m.isEnable);
            } catch(MigemoException e) {
                m = null;
            }
            return m;
        }
        else
        {
            return null;
        }
        assert(false);
    }

    static auto migemoInfo() @safe nothrow
    {
        import std.algorithm;
        import std.file;
        import std.range;
        import std.typecons;

        alias LibInfo = Tuple!(string, "lib", string, "dict");
        version(Windows)
        {
            version(X86)
            {
                enum candidates = [LibInfo.init];
            }
            else version(X86_64)
            {
                enum candidates = [LibInfo(`migemo.dll`, `resource\dict\dict`)];
            }
        }
        else version(linux)
        {
            import std.format;

            version(X86)
            {
                enum arch = "i386-linux-gnu";
            }
            else
            {
                enum arch = "x86_64-linux-gnu";
            }
            enum candidates = [
                // Arch
                LibInfo("/usr/lib/libmigemo.so", "/usr/share/migemo/utf-8"),
                // Debian/Ubuntu
                LibInfo(format("/usr/lib/%s/libmigemo.so.1", arch), "/usr/share/cmigemo/utf-8"),
                // Fedora
                LibInfo("/usr/lib/libmigemo.so.1", "/usr/share/cmigemo/utf-8"),
                ];
        }
        else version(OSX)
        {
            enum candidates = [LibInfo("/usr/local/opt/cmigemo/lib/libmigemo.dylib",
                                       "/usr/local/opt/cmigemo/share/migemo/utf-8")];
        }
        auto ret = candidates.find!(a => a.lib.exists);
        return ret.empty ? LibInfo.init : ret.front;
    }

    public Wisdom wisdom;
    Migemo migemo;
}
