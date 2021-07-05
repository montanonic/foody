# Feature Planning

## Price & Store Locations

We can add prices to ingredients, which reflects the cost they were bought at. This will let us quickly derive metrics around price-per-unit or price-per-weight to let us compare the value of ingredients from different stores!

When ingredients are given prices, it enables us to calculate the cost of recipes using ingredients on hand. When a recipe requires ingredients that we are missing, we can use our last-known prices to estimate costs.

If we wish to add the store our ingredients were purchased from too, we can compute our potential recipe prices based upon going to combinations of stores. For example, if all ingredients are available at both stores, it lets us do a quick comparison of which would be cheaper (and also see what our leftover ingredient amounts are if stores usually only have fixed quantities of things? this feels like a less important feature to worry about for starters). It also lets us calculate getting the cheapest ingredients from both stores and seeing how much we'd save by going to both. Of course, *quality* also matters. So in that vein, I'd say: wait until I experience a real-world use-case before doing too much up front.

But the corse idea of estimating a recipe cost, and comparing totals based upon which stores we go to (with the ability to "lock" ingredients to a store if we like the quality) is great! This will let us view recipes with cost ranges too, like "from _ to _ dollars", depending of course on where ingredients are sourced from.

All-in-all, keeping track of *where* ingredients were purchased when adding them, along with the prices purchased at, will give us a lot of flexibility down the line for extending features.

## Richer Ingredient Data

We can have a dedicated ingredient view (search driven + expand-in-place) that lets us add all possible data around an ingredient. This could include all the stores you can buy it from, the different quantities they sell it in and the associated price-points, and any notes about the item in general, and about the item quality at particular stores and combinations (for example, you might note that at Fred Meyer the small boxed arugula is lower quality than the large-boxed, and so on...).

Price points will also vary seasonally, and otherwise, so tracking price histories is also a useful and perhaps fun feature. Noting how prices change over time becomes automatic, as long as we track price each time.

One great thing though is that when we add the data, we'll get a lot of this rich info automatically: as long as you have a store context, and then the item name, quantity, and price, we'll be able to track price over time, at each particular store, and for every type of quantity. You yourself won't really need to edit anything unless you're trying to make a plan.

## Forming Recipes

When forming a recipe you'll get defaults that use-up existing, non

## Default Expirations

With items that don't have an expiration date, having a default guideline based upon the type of food item it is is a solid default. For example, Spinach might have a 3 day default expiration.

## Expiration Flow UI

When viewing current house ingredients, having a view of what's gonna go bad soon seems really useful, so that you can figure out a recipe that uses them before they go bad!

This means that as we accumulate recipes, we can start sifting through recipes that use up as many expired ingredients as possible. By click-selecting the ingredients, we can start filtering for recipes that use them. But, because some recipes won't overlap, being able to mouse-over different recipes and then visually seeing how they'll affect your food inventory will be useful.

To also deal with competing expiring ingredients, we could do "Meal Planning" vs. just recipe planning, where we figure out a multi-course meal (or just multiple meals to be prepared or eaten at different points) that use up more/all of the expired ingredients separately.

Expiration flow will be "Expires 5/7" -> "Expires on Friday" -> "Expires Tomorrow" -> "Expires Today!" -> "Expired"

## Meal Planning

Rather than limiting our UI to just having an active recipe that we're making, we could plan out recipes for the coming week or so. This will show our projected quantities over time

# On the Implementation

Glen's excel-inspired data-flow spreadsheet (flowsheets?) is a great example of an alternative implementation for this type of UI. Ultimately, we're just tracking a bunch of data, and we want to pipe that data into different areas. Having a larger 2D plane to organize our app into different data sections and dependencies honestly seems like a great and simple way to get features out efficiently while still having a comprehensible UI. It won't be as "clean" as a standard style implementation, but it would be easier. So I just want to note this as a reference point to come back to, because it's cool to implement something like this and all, but really it's pretty simple stuff, and the things that make it powerful are creating views based upon historical data that let us make quick decisions.

I love the grid that flow-sheets uses, and how that makes things clean by default. One could imagine larger cell sizes for different "types", and unifying everything to that size in a local area.

The cool thing about flowsheets is that you immediately get lists, arrays, and ordered dictionaries for *free*. Like, what???? Adding "Set" columns wouldn't be much of a stretch either. And there you go, immediately you have access to some of the most important data structures in computing.

So how might our app be implemented in flowsheets? Well, we'd have an ingredients cluster, and then a relational table of ingredient name to store, and the store will have quantities and prices of that ingredient. So the ingredient name to ingredient store+quantity+price+note is a one-to-many relationship. A date field would of course also accompany everything, and would be set to auto-generate to current.

When you add ingredients to the current ingredient list, it auto-populates the "all ingredients you've ever used" table. So here again we have a join with id of ingredient name, between current ingredients with their quantities, and a table of just ingredient names (not much of a join I guess). But it's that latter table that we use in our calculations, because it has everything we've ever used. So implied by this is the ability to have creation-logic mutate other tables. Is there a more functional way to do this? Yes, it would be: you just type in your ingredients and the quantity and so on, and then there are derived views from that. One of them is your current ingredients, and that's going to be the combo of acquired ingredients, and used ingredients (which is derived from recipes, and just throwing things away).

Immediately, thinking this way gives us so much more information, and we can play off that information more effortlessly.

Now let's think about how we might do recipes. First off a feature I'd add to flowsheets is that the whoe block of rows can be nested inside of a context, and doing this makes a sort of object where each row is an object instance. Why do this? meh, just namespacing reasons I guess. Maybe it's not useful. So anyways, recipe: well we need to know what ingredients a recipe uses! And that's one to many. But it's one to many in a way that is kind-of annoying: we don't want to type the recipe name over and over and over on the left with all of its ingredients on the right. Nor can we have fixed columns of ingredient numbers unless we want arbitrarily-limited ingredient counts...

The answer... a flowsheet is itself a nestable entity. And here maybe is where we do in fact want to namepace. So, RecipeIngredient includes a recipe name, and a quantity. The recipe name has a correspondance with the ingredients table. In this case, it's a belongs correspondance: this means that the name *must* be included in the ingredients table to be added. This means we have to re-think our ingredients table as not purely derived from our history ledger of all our ingredient transactions, because we have speculative ingredients too that we may not have yet acquired. Two possible solution paths are (1) soften the correspondence logic to just grey-out an ingredient that isn't known: this will help prevent mistypings while also not punishing not-acquired ingredients. (2) allow table entries to source from multiple tables, wherein we can say ingredients is a set derived from our active amounts history, unioned with, well, the very table we were working in: our recipe ingredients. So that means any recipe ingredient not already acquired will auto-show up in our ingredients list as long as we union it. By creating correspondence auto-complete, we can help ensure we type recipe names correctly (and not spinich) while also allowing for new ingredients. But even better, we can combine these two paths and add logic to change the color of the recipe if it's not in the table. However this creates a data-dependency issue: if the ingredients table is *also* derived from our recipe ingredients, then how can we know it's in the table or not to color it differently? One simple answer is that we actually have two different tables here: acquired ingredient names, and all ingredients, the *former* being what we reference in the coloration code, and the latter being the derived result of the acquired names unioned with recipe ingredients. This lets us refer to previously unaquired recipe ingredients everywhere in our app. To extend this further, we can just have a "future ingredients" table if we want to start adding data for ingredients that we don't yet have, the ingredients table then also unions these.

This notion of nestable entity might need to be questionable. In databases, we'd flatten the representation into ids and joins. Such a scheme here means that the recipe name would have as its entry the id of an ingredient list, so to speak. But again, in DBs everything's flat, so an ingredient list table would really just be

17 spinach 5oz
17 milk 3oz
17 garlic 5
18 chocolate bar 10oz
18 cream 4cups

and so on.

To get the feature of a programming language, we can... use javascript's eval! Wow! But like actually, why not? All the data is immediately computed, so type errors are just obvious. To make this work with Elm we'd maybe want a webcomponent, but we could also try ports if they didn't introduce much friction.