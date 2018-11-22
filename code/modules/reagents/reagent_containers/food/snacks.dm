//Food items that are eaten normally and don't leave anything behind.
/obj/item/weapon/reagent_containers/food/snacks
	name = "snack"
	desc = "yummy"
	icon = 'icons/obj/food.dmi'
	icon_state = null
	var/bitesize = 1
	var/bitecount = FALSE
	var/trash = null
	var/slice_path
	var/slices_num
	var/dried_type = null
	var/dry = FALSE
	var/nutriment_amt = FALSE
	var/list/nutriment_desc = list("food" = 1)
	center_of_mass = list("x"=16, "y"=16)
	w_class = 2

// dynamically scaled bitesizes, now people can eat everything faster - Kachnov
/obj/item/weapon/reagent_containers/food/snacks/New()
	..()
	if (nutriment_amt)
		reagents.add_reagent("nutriment",nutriment_amt,nutriment_desc)
	spawn (1)
		bitesize = max(bitesize, ceil(reagents.total_volume/5))
	value = 2*nutriment_amt

	//Placeholder for effect that trigger on eating that aren't tied to reagents.
/obj/item/weapon/reagent_containers/food/snacks/proc/On_Consume(var/mob/M)
	if (!usr)	return
	if (raw)
		M.reagents.add_reagent("food_poisoning", 1)
	if (!reagents.total_volume)
		M.visible_message("<span class='notice'>[M] finishes eating \the [src].</span>","<span class='notice'>You finish eating \the [src].</span>")
		usr.drop_from_inventory(src)	//so icons update :[

		if (trash)
			if (ispath(trash,/obj/item))
				var/obj/item/TrashItem = new trash(usr)
				usr.put_in_hands(TrashItem)
			else if (istype(trash,/obj/item))
				usr.put_in_hands(trash)
		qdel(src)
	return

/obj/item/weapon/reagent_containers/food/snacks/attack_self(mob/user as mob)
	return

/obj/item/weapon/reagent_containers/food/snacks/attack(mob/M as mob, mob/user as mob, def_zone)
	if (!reagents.total_volume)
		user << "<span class='danger'>None of [src] left!</span>"
		user.drop_from_inventory(src)
		qdel(src)
		return FALSE

	if (istype(M, /mob/living/carbon))
		//TODO: replace with standard_feed_mob() call.
		var/mob/living/carbon/C = M
		var/fullness = C.get_fullness()
		if (C == user)								//If you're eating it yourself
			if (istype(C,/mob/living/carbon/human))
				var/mob/living/carbon/human/H = M
				if (!H.check_has_mouth())
					user << "Where do you intend to put \the [src]? You don't have a mouth!"
					return
				var/obj/item/blocked = H.check_mouth_coverage()
				if (blocked)
					user << "<span class='warning'>\The [blocked] is in the way!</span>"
					return

			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN) //puts a limit on how fast people can eat/drink things
			if (fullness <= 50)
				C << "<span class='danger'>You hungrily chew out a piece of [src] and gobble it!</span>"
			if (fullness > 50 && fullness <= 150)
				C << "<span class='notice'>You hungrily begin to eat [src].</span>"
			if (fullness > 150 && fullness <= 350)
				C << "<span class='notice'>You take a bite of [src].</span>"
			if (fullness > 350 && fullness <= 550)
				C << "<span class='notice'>You take a bite of [src].</span>"
			if (fullness > 580)
				C << "<span class='danger'>You cannot force any more of [src] to go down your throat.</span>"
				return FALSE
		else
			if (!M.can_force_feed(user, src))
				return

			if (fullness <= 580)
				user.visible_message("<span class='danger'>[user] attempts to feed [M] [src].</span>")
			else
				user.visible_message("<span class='danger'>[user] cannot force anymore of [src] down [M]'s throat.</span>")
				return FALSE

			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			if (!do_after(user, 30, M, check_for_repeats = FALSE)) return

			M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been fed [name] by [user.name] ([user.ckey]) Reagents: [reagentlist(src)]</font>")
			user.attack_log += text("\[[time_stamp()]\] <font color='red'>Fed [name] by [M.name] ([M.ckey]) Reagents: [reagentlist(src)]</font>")
			msg_admin_attack("[key_name(user)] fed [key_name(M)] with [name] Reagents: [reagentlist(src)] (INTENT: [uppertext(user.a_intent)])")

			user.visible_message("<span class='danger'>[user] feeds [M] [src].</span>")

		if (reagents)								//Handle ingestion of the reagent.
			playsound(M.loc,'sound/items/eatfood.ogg', rand(10,50), TRUE)
			if (reagents.total_volume)
				if (reagents.total_volume > bitesize)
					reagents.trans_to_mob(M, bitesize, CHEM_INGEST)
				else
					reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
				bitecount++
				On_Consume(M)
			return TRUE

	return FALSE

/obj/item/weapon/reagent_containers/food/snacks/examine(mob/user)
	if (!..(user, TRUE))
		return
	if (bitecount==0)
		return
	else if (bitecount==1)
		user << "<span class='notice'>\The [src] was bitten by someone!</span>"
	else if (bitecount<=3)
		user << "<span class='notice'>\The [src] was bitten [bitecount] time\s!</span>"
	else
		user << "<span class='notice'>\The [src] was bitten multiple times!</span>"

/obj/item/weapon/reagent_containers/food/snacks/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/storage) && user.a_intent != I_HURT)
		..() // -> item/attackby()
		return

	// Eating with forks
	if (istype(W,/obj/item/weapon/material/kitchen/utensil) && !istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		var/obj/item/weapon/material/kitchen/utensil/U = W
		if (U.scoop_food)
			if (!U.reagents)
				U.create_reagents(5)

			if (U.reagents.total_volume > 0)
				user << "<span class='warning'>You already have something on your [U].</span>"
				return

			user.visible_message( \
				"\The [user] scoops up some [src] with \the [U]!", \
				"<span class='notice'>You scoop up some [src] with \the [U]!</span>" \
			)

			bitecount++
			U.overlays.Cut()
			U.loaded = "[src]"
			var/image/I = new(U.icon, "loadedfood")
			I.color = filling_color
			U.overlays += I

			reagents.trans_to_obj(U, min(reagents.total_volume,5))

			if (reagents.total_volume <= 0)
				qdel(src)
			return

	else if (is_sliceable() && !istype(W, /obj/item/weapon/reagent_containers/food/drinks) && !istype(W, /obj/item/weapon/reagent_containers/glass))
		//these are used to allow hiding edge items in food that is not on a table/tray

		var/can_slice_here = FALSE
		if (isturf(loc))
			if (locate(/obj/structure/table) in loc)
				can_slice_here = TRUE
			else if (locate(/obj/structure/optable) in loc)
				can_slice_here = TRUE

		var/hide_item = (!W.edge || !can_slice_here)

		if (hide_item)
			if (contents.len)
				user << "<span class='danger'>There's already something inside \the [src].</span>"
				return
			if (W.w_class >= w_class)
				user << "<span class='warning'>\the [W] is too big to hide inside \the [src].</span>"
				return

			user << "<span class='warning'>You slip \the [W] inside \the [src].</span>"
			user.remove_from_mob(W)
			W.dropped(user)
			add_fingerprint(user)
			contents += W
			return

		else if (W.edge)
			if (!can_slice_here)
				user << "<span class='warning'>You cannot slice \the [src] here! You need a table or at least a tray to do it.</span>"
				return

			var/slices_lost = 0
			if (W.w_class > 3)
				user.visible_message("<span class='notice'>\The [user] crudely slices \the [src] with [W]!</span>", "<span class='notice'>You crudely slice \the [src] with your [W]!</span>")
				slices_lost = rand(1,min(1,round(slices_num/2)))
			else
				user.visible_message("<span class='notice'>\The [user] slices \the [src]!</span>", "<span class='notice'>You slice \the [src]!</span>")

			var/reagents_per_slice = reagents.total_volume/slices_num
			for (var/i=1 to (slices_num-slices_lost))
				var/obj/slice = new slice_path (loc)
				reagents.trans_to_obj(slice, reagents_per_slice)
			qdel(src)
			return

/obj/item/weapon/reagent_containers/food/snacks/proc/is_sliceable()
	return (slices_num && slice_path && slices_num > 0)

/obj/item/weapon/reagent_containers/food/snacks/Destroy()
	if (contents)
		for (var/atom/movable/something in contents)
			something.loc = get_turf(src)
	..()

////////////////////////////////////////////////////////////////////////////////
/// FOOD END
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/attack_generic(var/mob/living/user)
	if (!isanimal(user))
		return
	user.visible_message("<b>[user]</b> nibbles away at \the [src].","You nibble away at \the [src].")
	bitecount++
	if (reagents && user.reagents)
		reagents.trans_to_mob(user, bitesize, CHEM_INGEST)
	spawn(5)
		if (!src && !user.client)
			user.custom_emote(1,"[pick("burps", "cries for more", "burps twice", "looks at the area where the food was")]")
			qdel(src)
	On_Consume(user)

//////////////////////////////////////////////////
////////////////////////////////////////////Snacks
//////////////////////////////////////////////////
//Items in the "Snacks" subcategory are food items that people actually eat. The key points are that they are created
//	already filled with reagents and are destroyed when empty. Additionally, they make a "munching" noise when eaten.

//Notes by Darem: Food in the "snacks" subtype can hold a maximum of 50 units Generally speaking, you don't want to go over 40
//	total for the item because you want to leave space for extra condiments. If you want effect besides healing, add a reagent for
//	it. Try to stick to existing reagents when possible (so if you want a stronger healing effect, just use Tricordrazine). On use
//	effect (such as the old officer eating a donut code) requires a unique reagent (unless you can figure out a better way).

//The nutriment reagent and bitesize variable replace the old heal_amt and amount variables. Each unit of nutriment is equal to
//	2 of the old heal_amt variable. Bitesize is the rate at which the reagents are consumed. So if you have 6 nutriment and a
//	bitesize of 2, then it'll take 3 bites to eat. Unlike the old system, the contained reagents are evenly spread among all
//	the bites. No more contained reagents = no more bites.

//Here is an example of the new formatting for anyone who wants to add more food items.
///obj/item/weapon/reagent_containers/food/snacks/xenoburger			//Identification path for the object.
//	name = "Xenoburger"													//Name that displays in the UI.
//	desc = "Smells caustic. Tastes like heresy."						//Duh
//	icon_state = "xburger"												//Refers to an icon in food.dmi
//	New()																//Don't mess with this.
//		..()															//Same here.
//		reagents.add_reagent("xenomicrobes", 10)						//This is what is in the food item. you may copy/paste
//		reagents.add_reagent("nutriment", 2)							//	this line of code for all the contents.
//		bitesize = 3													//This is the amount each bite consumes.
/obj/item/weapon/reagent_containers/food/snacks/hardtack
	name = "hardtack"
	desc = "Looks like it has been in a ship's hull for years."
	icon_state = "hardtack1"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 2
	nutriment_desc = list("salt" = 1, "flour" = 2)
	New()
		..()
		bitesize = 2
		icon_state = "hardtack[rand(1,2)]"

/obj/item/weapon/reagent_containers/food/snacks/driedmeat
	name = "dried meat"
	desc = "Dried meat. Probably pork. Or mice."
	icon_state = "driedmeat"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 3
	nutriment_desc = list("salt" = 3, "meat" = 1)
	New()
		..()
		bitesize = 2
/obj/item/weapon/reagent_containers/food/snacks/driedfish
	name = "salted fish"
	desc = "Some kind of fish. Very salty, wash it down with something,"
	icon_state = "driedfish"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 3
	nutriment_desc = list("salt" = 3, "fish" = 1)
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/pickle
	name = "pickle"
	desc = "A pickle. That's it."
	icon_state = "pickle"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 1
	nutriment_desc = list("vinegar" = 3)
	New()
		..()
		bitesize = 1
/obj/item/weapon/reagent_containers/food/snacks/pickle/big
	name = "big pickle"
	desc = "Oh boy, that's a big pickle!"
	icon_state = "pickleb"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 5
	nutriment_desc = list("vinegar" = 5)
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/cookie
	name = "cookie"
	desc = "COOKIE!!!"
	icon_state = "COOKIE!!!"
	filling_color = "#DBC94F"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 3, "cookie" = 2)
	New()
		..()
		bitesize = 1


/obj/item/weapon/reagent_containers/food/snacks/egg
	name = "egg"
	desc = "An egg!"
	icon_state = "egg"
	filling_color = "#FDFFD1"
	volume = 10
	center_of_mass = list("x"=16, "y"=13)

/obj/item/weapon/reagent_containers/food/snacks/egg/New()
	..()
	reagents.add_reagent("egg", 3)

/obj/item/weapon/reagent_containers/food/snacks/egg/afterattack(obj/O as obj, mob/user as mob, proximity)
/*	if (istype(O,/obj/structure/microwave))
		return ..()*/
	if (istype(O, /obj/structure/pot))
		return

	if (!(proximity && O.is_open_container()))
		return
	user << "You crack \the [src] into \the [O]."
	reagents.trans_to(O, reagents.total_volume)
	user.drop_from_inventory(src)
	qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/egg/throw_impact(atom/hit_atom)
	..()
	new/obj/effect/decal/cleanable/egg_smudge(loc)
	reagents.splash(hit_atom, reagents.total_volume)
	visible_message("<span class='warning'>\The [src] has been squashed!</span>","<span class='warning'>You hear a smack.</span>")
	qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/egg/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype( W, /obj/item/weapon/pen/crayon ))
		var/obj/item/weapon/pen/crayon/C = W
		var/clr = C.colourName

		if (!(clr in list("blue","green","mime","orange","purple","rainbow","red","yellow")))
			usr << "<span class='notice'>The egg refuses to take on this color!</span>"
			return

		usr << "<span class='notice'>You color \the [src] [clr]</span>"
		icon_state = "egg-[clr]"
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/egg/blue
	icon_state = "egg-blue"

/obj/item/weapon/reagent_containers/food/snacks/egg/green
	icon_state = "egg-green"

/obj/item/weapon/reagent_containers/food/snacks/egg/mime
	icon_state = "egg-mime"

/obj/item/weapon/reagent_containers/food/snacks/egg/orange
	icon_state = "egg-orange"

/obj/item/weapon/reagent_containers/food/snacks/egg/purple
	icon_state = "egg-purple"

/obj/item/weapon/reagent_containers/food/snacks/egg/rainbow
	icon_state = "egg-rainbow"

/obj/item/weapon/reagent_containers/food/snacks/egg/red
	icon_state = "egg-red"

/obj/item/weapon/reagent_containers/food/snacks/egg/yellow
	icon_state = "egg-yellow"

/obj/item/weapon/reagent_containers/food/snacks/friedegg
	name = "Fried egg"
	desc = "A fried egg, with a touch of salt and pepper."
	icon_state = "friedegg"
	filling_color = "#FFDF78"
	center_of_mass = list("x"=16, "y"=14)

	New()
		..()
		reagents.add_reagent("protein", 3)
		reagents.add_reagent("sodiumchloride", 1)
		reagents.add_reagent("blackpepper", 1)
		bitesize = 1

/obj/item/weapon/reagent_containers/food/snacks/boiledegg
	name = "Boiled egg"
	desc = "A hard boiled egg."
	icon_state = "egg"
	filling_color = "#FFFFFF"

	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/organ
	name = "organ"
	desc = "It's good for you."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "appendix"
	filling_color = "#E00D34"
	center_of_mass = list("x"=16, "y"=16)
	raw = TRUE

	New()
		..()
		reagents.add_reagent("protein", rand(3,5))
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/tofu
	name = "Tofu"
	icon_state = "tofu"
	desc = "We all love tofu."
	filling_color = "#FFFEE0"
	center_of_mass = list("x"=17, "y"=10)
	nutriment_amt = 3
	nutriment_desc = list("tofu" = 3, "goeyness" = 3)
	New()
		..()
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/tofurkey
	name = "Tofurkey"
	desc = "A fake turkey made from tofu."
	icon_state = "tofurkey"
	filling_color = "#FFFEE0"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_amt = 12
	nutriment_desc = list("turkey" = 3, "tofu" = 5, "goeyness" = 4)

	New()
		..()
		reagents.add_reagent("stoxin", 3)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/stuffing
	name = "Stuffing"
	desc = "Moist, peppery breadcrumbs for filling the body cavities of dead birds. Dig in!"
	icon_state = "stuffing"
	filling_color = "#C9AC83"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_amt = 3
	nutriment_desc = list("dryness" = 2, "bread" = 2)
	New()
		..()
		bitesize = 1

/obj/item/weapon/reagent_containers/food/snacks/fishfillet
	name = "fish fillet"
	desc = "A fillet of fish."
	icon_state = "fishfillet"
	filling_color = "#FFDEFE"
	center_of_mass = list("x"=17, "y"=13)
	var/rotten = FALSE
	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("food_poisoning", 1)
		bitesize = 6
		spawn(2400) //4 minutes
			icon_state = "rottenfillet"
			name = "rotten [name]"
			rotten = TRUE
			reagents.add_reagent("food_poisoning", 1)
			spawn(3000)
				qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/fishfingers
	name = "Fish Fingers"
	desc = "A finger of fish."
	icon_state = "fishfingers"
	filling_color = "#FFDEFE"
	center_of_mass = list("x"=16, "y"=13)

	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("carpotoxin", 3)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/hugemushroomslice
	name = "huge mushroom slice"
	desc = "A slice from a huge mushroom."
	icon_state = "hugemushroomslice"
	filling_color = "#E0D7C5"
	center_of_mass = list("x"=17, "y"=16)
	nutriment_amt = 3
	nutriment_desc = list("raw" = 2, "mushroom" = 2)
	New()
		..()
		reagents.add_reagent("psilocybin", 3)
		bitesize = 6

/obj/item/weapon/reagent_containers/food/snacks/tomatomeat
	name = "tomato slice"
	desc = "A slice from a huge tomato"
	icon_state = "tomatomeat"
	filling_color = "#DB0000"
	center_of_mass = list("x"=17, "y"=16)
	nutriment_amt = 3
	nutriment_desc = list("raw" = 2, "tomato" = 3)
	New()
		..()
		bitesize = 6

/obj/item/weapon/reagent_containers/food/snacks/bearmeat
	name = "bear meat"
	desc = "A very manly slab of meat."
	icon_state = "bearmeat"
	filling_color = "#DB0000"
	center_of_mass = list("x"=16, "y"=10)
	raw = TRUE

	New()
		..()
		reagents.add_reagent("protein", 12)
		reagents.add_reagent("hyperzine", 5)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/bearmeat/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!roasted && (istype(W,/obj/item/weapon/material/knife) || istype(W,/obj/item/weapon/material/kitchen/utensil/knife)))
		var/atom/A = new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		A.name = "bear meat cutlet"
		A.desc = replacetext(desc, "slab", "cutlet")
		A = new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		A.name = "bear meat cutlet"
		A.desc = replacetext(desc, "slab", "cutlet")
		A = new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		A.name = "bear meat cutlet"
		A.desc = replacetext(desc, "slab", "cutlet")
		user << "You cut the meat into thin strips."
		qdel(src)
	else
		..()


/obj/item/weapon/reagent_containers/food/snacks/meatball
	name = "meatball"
	desc = "A great meal all round."
	icon_state = "meatball"
	filling_color = "#DB0000"
	center_of_mass = list("x"=16, "y"=16)

	New()
		..()
		reagents.add_reagent("protein", 3)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/sausage
	name = "Sausage"
	desc = "A piece of mixed, long meat."
	icon_state = "sausage"
	filling_color = "#DB0000"
	center_of_mass = list("x"=16, "y"=16)

	New()
		..()
		reagents.add_reagent("protein", 6)
		bitesize = 2


/obj/item/weapon/reagent_containers/food/snacks/omelette
	name = "Omelette Du Fromage"
	desc = "That's all you can say!"
	icon_state = "omelette"
	trash = /obj/item/kitchen/plate
	filling_color = "#FFF9A8"
	center_of_mass = list("x"=16, "y"=13)

	//var/herp = FALSE
	New()
		..()
		reagents.add_reagent("protein", 8)
		bitesize = 1

/obj/item/weapon/reagent_containers/food/snacks/muffin
	name = "Muffin"
	desc = "A delicious and spongy little cake"
	icon_state = "muffin"
	filling_color = "#E0CF9B"
	center_of_mass = list("x"=17, "y"=4)
	nutriment_desc = list("sweetness" = 3, "muffin" = 3)
	nutriment_amt = 6
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/berryclafoutis
	name = "Berry Clafoutis"
	desc = "No black birds, this is a good sign."
	icon_state = "berryclafoutis"
	trash = /obj/item/kitchen/plate
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("sweetness" = 2, "pie" = 3)
	nutriment_amt = 4
	New()
		..()
		reagents.add_reagent("berryjuice", 5)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/waffles
	name = "waffles"
	desc = "Mmm, waffles"
	icon_state = "waffles"
	trash = /obj/item/trash
	filling_color = "#E6DEB5"
	center_of_mass = list("x"=15, "y"=11)
	nutriment_desc = list("waffle" = 8)
	nutriment_amt = 8
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/eggplantparm
	name = "Eggplant Parmigiana"
	desc = "The only good recipe for eggplant."
	icon_state = "eggplantparm"
	trash = /obj/item/kitchen/plate
	filling_color = "#4D2F5E"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("cheese" = 3, "eggplant" = 3)
	nutriment_amt = 6
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/meatpie
	name = "Meat-pie"
	icon_state = "meatpie"
	desc = "An old barber recipe, very delicious!"
	trash = /obj/item/kitchen/plate
	filling_color = "#948051"
	center_of_mass = list("x"=16, "y"=13)

	New()
		..()
		reagents.add_reagent("protein", 10)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/tofupie
	name = "Tofu-pie"
	icon_state = "meatpie"
	desc = "A delicious tofu pie."
	trash = /obj/item/kitchen/plate
	filling_color = "#FFFEE0"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("tofu" = 2, "pie" = 8)
	nutriment_amt = 10
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/amanita_pie
	name = "amanita pie"
	desc = "Sweet and tasty poison pie."
	icon_state = "amanita_pie"
	filling_color = "#FFCCCC"
	center_of_mass = list("x"=17, "y"=9)
	nutriment_desc = list("sweetness" = 3, "mushroom" = 3, "pie" = 2)
	nutriment_amt = 5
	New()
		..()
		reagents.add_reagent("amatoxin", 3)
		reagents.add_reagent("psilocybin", 1)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/plump_pie
	name = "plump pie"
	desc = "I bet you love stuff made out of plump helmets!"
	icon_state = "plump_pie"
	filling_color = "#B8279B"
	center_of_mass = list("x"=17, "y"=9)
	nutriment_desc = list("heartiness" = 2, "mushroom" = 3, "pie" = 3)
	nutriment_amt = 8
	New()
		..()
		if (prob(10))
			name = "exceptional plump pie"
			desc = "Microwave is taken by a fey mood! It has cooked an exceptional plump pie!"
			reagents.add_reagent("tricordrazine", 5)
			bitesize = 2


/obj/item/weapon/reagent_containers/food/snacks/loadedbakedpotato
	name = "Loaded Baked Potato"
	desc = "Totally baked."
	icon_state = "loadedbakedpotato"
	filling_color = "#9C7A68"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("baked potato" = 3)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("protein", 3)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/fries
	name = "Space Fries"
	desc = "AKA: French Fries, Freedom Fries, etc."
	icon_state = "fries"
	trash = /obj/item/kitchen/plate
	filling_color = "#EDDD00"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("fresh fries" = 4)
	nutriment_amt = 4
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/spaghetti
	name = "Spaghetti"
	desc = "A bundle of raw spaghetti."
	icon_state = "spagetti"
	filling_color = "#EDDD00"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_desc = list("noodles" = 2)
	nutriment_amt = 1
	New()
		..()
		bitesize = 1

/obj/item/weapon/reagent_containers/food/snacks/badrecipe
	name = "Burned mess"
	desc = "Someone should be demoted from chef for this."
	icon_state = "badrecipe"
	filling_color = "#211F02"
	center_of_mass = list("x"=16, "y"=12)

	New()
		..()
		reagents.add_reagent("toxin", 1)
		reagents.add_reagent("carbon", 3)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/meatsteak
	name = "Meat steak"
	desc = "A piece of hot spicy meat."
	icon_state = "meatstake"
	trash = /obj/item/kitchen/plate
	filling_color = "#7A3D11"
	center_of_mass = list("x"=16, "y"=13)

	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("sodiumchloride", 1)
		reagents.add_reagent("blackpepper", 1)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/poppypretzel
	name = "Poppy pretzel"
	desc = "It's all twisted up!"
	icon_state = "poppypretzel"
	bitesize = 2
	filling_color = "#916E36"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("poppy seeds" = 2, "pretzel" = 3)
	nutriment_amt = 5
	New()
		..()
		bitesize = 2


/obj/item/weapon/reagent_containers/food/snacks/meatballsoup
	name = "Meatball soup"
	desc = "You've got balls kid, BALLS!"
	icon_state = "meatballsoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#785210"
	center_of_mass = list("x"=16, "y"=8)

	New()
		..()
		reagents.add_reagent("protein", 8)
		reagents.add_reagent("water", 15)
		bitesize = 5


/obj/item/weapon/reagent_containers/food/snacks/vegetablesoup
	name = "Vegetable soup"
	desc = "A true vegan meal" //TODO
	icon_state = "vegetablesoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#AFC4B5"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_desc = list("carot" = 2, "corn" = 2, "eggplant" = 2, "potato" = 2)
	nutriment_amt = 8
	New()
		..()
		reagents.add_reagent("water", 15)
		bitesize = 5


/obj/item/weapon/reagent_containers/food/snacks/baguette
	name = "Baguette"
	desc = "Bon appetit!"
	icon_state = "baguette"
	filling_color = "#E3D796"
	center_of_mass = list("x"=18, "y"=12)
	nutriment_desc = list("french bread" = 6)
	nutriment_amt = 6
	New()
		..()
		reagents.add_reagent("blackpepper", 1)
		reagents.add_reagent("sodiumchloride", 1)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/fishandchips
	name = "Fish and Chips"
	desc = "I do say so myself chap."
	icon_state = "fishandchips"
	filling_color = "#E3D796"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_desc = list("salt" = 1, "chips" = 3)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("protein", 3)
		reagents.add_reagent("carpotoxin", 3)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/sandwich
	name = "Sandwich"
	desc = "A grand creation of meat, cheese, bread, and several leaves of lettuce! Arthur Dent would be proud."
	icon_state = "sandwich"
	trash = /obj/item/kitchen/plate
	filling_color = "#D9BE29"
	center_of_mass = list("x"=16, "y"=4)
	nutriment_desc = list("bread" = 3, "cheese" = 3)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("protein", 3)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/toastedsandwich
	name = "Toasted Sandwich"
	desc = "Now if you only had a pepper bar."
	icon_state = "toastedsandwich"
	trash = /obj/item/kitchen/plate
	filling_color = "#D9BE29"
	center_of_mass = list("x"=16, "y"=4)
	nutriment_desc = list("toasted bread" = 3, "cheese" = 3)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("protein", 3)
		reagents.add_reagent("carbon", 2)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/grilledcheese
	name = "Grilled Cheese Sandwich"
	desc = "Goes great with Tomato soup!"
	icon_state = "toastedsandwich"
	trash = /obj/item/kitchen/plate
	filling_color = "#D9BE29"
	nutriment_desc = list("toasted bread" = 3, "cheese" = 3)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("protein", 4)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/tomatosoup
	name = "Tomato Soup"
	desc = "Drinking this feels like being a vampire! A tomato vampire..."
	icon_state = "tomatosoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#D92929"
	center_of_mass = list("x"=16, "y"=7)
	nutriment_desc = list("soup" = 5)
	nutriment_amt = 5
	New()
		..()
		reagents.add_reagent("tomatojuice", 10)
		bitesize = 3
/*
/obj/item/weapon/reagent_containers/food/snacks/rofflewaffles
	name = "Roffle Waffles"
	desc = "Waffles from Roffle. Co."
	icon_state = "rofflewaffles"
	trash = /obj/item/trash/waffles
	filling_color = "#FF00F7"
	center_of_mass = list("x"=15, "y"=11)
	nutriment_desc = list("waffle" = 7, "sweetness" = 1)
	nutriment_amt = 8
	New()
		..()
		reagents.add_reagent("psilocybin", 8)
		bitesize = 4
*/
/obj/item/weapon/reagent_containers/food/snacks/stew
	name = "Stew"
	desc = "A nice and warm stew. Healthy and strong."
	icon_state = "stew"
	filling_color = "#9E673A"
	center_of_mass = list("x"=16, "y"=5)
	nutriment_desc = list("tomato" = 2, "potato" = 2, "carrot" = 2, "eggplant" = 2, "mushroom" = 2)
	nutriment_amt = 5
	trash = /obj/item/kitchen/snack_bowl
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("tomatojuice", 5)
		reagents.add_reagent("water", 30)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/stew_wood
	name = "Stew"
	desc = "A nice and warm stew. Healthy and strong."
	icon_state = "stew_wood"
	filling_color = "#9E673A"
	center_of_mass = list("x"=16, "y"=5)
	nutriment_desc = list("tomato" = 2, "potato" = 2, "carrot" = 2, "meat" = 2, "mushroom" = 2)
	nutriment_amt = 5
	trash = /obj/item/kitchen/wood_bowl
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("tomatojuice", 5)
		reagents.add_reagent("water", 30)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast
	name = "Jellied Toast"
	desc = "A slice of bread covered with delicious jam."
	icon_state = "jellytoast"
	trash = /obj/item/kitchen/plate
	filling_color = "#B572AB"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_desc = list("toasted bread" = 2)
	nutriment_amt = 1
	New()
		..()
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast/cherry
	New()
		..()
		reagents.add_reagent("cherryjelly", 5)
/*
/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast/slime
	New()
		..()
		reagents.add_reagent("slimejelly", 5)

/obj/item/weapon/reagent_containers/food/snacks/jellyburger
	name = "Jelly Burger"
	desc = "Culinary delight..?"
	icon_state = "jellyburger"
	filling_color = "#B572AB"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("buns" = 5)
	nutriment_amt = 5
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/jellyburger/slime
	New()
		..()
		reagents.add_reagent("slimejelly", 5)

/obj/item/weapon/reagent_containers/food/snacks/jellyburger/cherry
	New()
		..()
		reagents.add_reagent("cherryjelly", 5)

/obj/item/weapon/reagent_containers/food/snacks/milosoup
	name = "Milosoup"
	desc = "The universes best soup! Yum!!!"
	icon_state = "milosoup"
	trash = /obj/item/kitchen/snack_bowl
	center_of_mass = list("x"=16, "y"=7)
	nutriment_desc = list("soy" = 8)
	nutriment_amt = 8
	New()
		..()
		reagents.add_reagent("water", 5)
		bitesize = 4

/obj/item/weapon/reagent_containers/food/snacks/stewedsoymeat
	name = "Stewed Soy Meat"
	desc = "Even non-vegetarians will LOVE this!"
	icon_state = "stewedsoymeat"
	trash = /obj/item/kitchen/plate
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("soy" = 4, "tomato" = 4)
	nutriment_amt = 8
	New()
		..()
		bitesize = 2
*/
/obj/item/weapon/reagent_containers/food/snacks/boiledspagetti
	name = "Boiled Spaghetti"
	desc = "A plain dish of noodles, this sucks."
	icon_state = "spagettiboiled"
	trash = /obj/item/kitchen/plate
	filling_color = "#FCEE81"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("noodles" = 2)
	nutriment_amt = 2
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/boiledspagetti/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meatball))
		visible_message("<span class = 'notice'>[user] combines the spaghetti with the meatball to make spaghetti and meatballs.</span>")
		qdel(I)
		new/obj/item/weapon/reagent_containers/food/snacks/meatballspagetti(get_turf(src))
		qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/boiledrice
	name = "Boiled Rice"
	desc = "A boring dish of boring rice."
	icon_state = "boiledrice"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#FFFBDB"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("rice" = 2)
	nutriment_amt = 2
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/ricepudding
	name = "Rice Pudding"
	desc = "Where's the jam?"
	icon_state = "rpudding"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#FFFBDB"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("rice" = 2)
	nutriment_amt = 4
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/pastatomato
	name = "Spaghetti"
	desc = "Spaghetti and crushed tomatoes. Just like your abusive father used to make!"
	icon_state = "pastatomato"
	trash = /obj/item/kitchen/plate
	filling_color = "#DE4545"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("tomato" = 3, "noodles" = 3)
	nutriment_amt = 6
	New()
		..()
		reagents.add_reagent("tomatojuice", 10)
		bitesize = 4

/obj/item/weapon/reagent_containers/food/snacks/meatballspagetti
	name = "Spaghetti & Meatballs"
	desc = "Now thats a nic'e meatball!"
	icon_state = "meatballspagetti"
	trash = /obj/item/kitchen/plate
	filling_color = "#DE4545"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("noodles" = 4)
	nutriment_amt = 4
	New()
		..()
		reagents.add_reagent("protein", 4)
		bitesize = 2

/*
/obj/item/weapon/reagent_containers/food/snacks/spesslaw
	name = "Spesslaw"
	desc = "A lawyers favourite"
	icon_state = "spesslaw"
	filling_color = "#DE4545"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("noodles" = 4)
	nutriment_amt = 4
	New()
		..()
		reagents.add_reagent("protein", 4)
		bitesize = 2
*/
/obj/item/weapon/reagent_containers/food/snacks/carrotfries
	name = "Carrot Fries"
	desc = "Tasty fries from fresh Carrots."
	icon_state = "carrotfries"
	trash = /obj/item/kitchen/plate
	filling_color = "#FAA005"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("carrot" = 3, "salt" = 1)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("imidazoline", 3)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/candiedapple
	name = "Candied Apple"
	desc = "An apple coated in sugary sweetness."
	icon_state = "candiedapple"
	filling_color = "#F21873"
	center_of_mass = list("x"=15, "y"=13)
	nutriment_desc = list("apple" = 3, "caramel" = 3, "sweetness" = 2)
	nutriment_amt = 3
	New()
		..()
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/applepie
	name = "Apple Pie"
	desc = "A pie containing sweet sweet love... or apple."
	icon_state = "applepie"
	filling_color = "#E0EDC5"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("sweetness" = 2, "apple" = 2, "pie" = 2)
	nutriment_amt = 4
	New()
		..()
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/cherrypie
	name = "Cherry Pie"
	desc = "Taste so good, make a grown man cry."
	icon_state = "cherrypie"
	filling_color = "#FF525A"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("sweetness" = 2, "cherry" = 2, "pie" = 2)
	nutriment_amt = 4
	New()
		..()
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/twobread
	name = "Two Bread"
	desc = "It is very bitter and winy."
	icon_state = "twobread"
	filling_color = "#DBCC9A"
	center_of_mass = list("x"=15, "y"=12)
	nutriment_desc = list("sourness" = 2, "bread" = 2)
	nutriment_amt = 2
	New()
		..()
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/jellysandwich
	name = "Jelly Sandwich"
	desc = "You wish you had some peanut butter to go with this..."
	icon_state = "jellysandwich"
	trash = /obj/item/kitchen/plate
	filling_color = "#9E3A78"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_desc = list("bread" = 2)
	nutriment_amt = 2
	New()
		..()
		bitesize = 3

/*
/obj/item/weapon/reagent_containers/food/snacks/jellysandwich/slime
	New()
		..()
		reagents.add_reagent("slimejelly", 5)
*/

/obj/item/weapon/reagent_containers/food/snacks/jellysandwich/cherry
	New()
		..()
		reagents.add_reagent("cherryjelly", 5)

/*
/obj/item/weapon/reagent_containers/food/snacks/boiledslimecore
	name = "Boiled slime Core"
	desc = "A boiled red thing."
	icon_state = "boiledslimecore" //nonexistant?
	New()
		..()
		reagents.add_reagent("slimejelly", 5)
		bitesize = 3
*/

/obj/item/weapon/reagent_containers/food/snacks/mint
	name = "mint"
	desc = "it is only wafer thin."
	icon_state = "mint"
	filling_color = "#F2F2F2"
	center_of_mass = list("x"=16, "y"=14)

	New()
		..()
		reagents.add_reagent("mint", 1)
		bitesize = 1

/obj/item/weapon/reagent_containers/food/snacks/mushroomsoup
	name = "mushroom soup"
	desc = "A delicious and hearty mushroom soup."
	icon_state = "mushroomsoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#E386BF"
	center_of_mass = list("x"=17, "y"=10)
	nutriment_desc = list("mushroom" = 8, "milk" = 2)
	nutriment_amt = 8
	New()
		..()
		bitesize = 2
		reagents.add_reagent("water", 30)
/*
/obj/item/weapon/reagent_containers/food/snacks/plumphelmetbiscuit
	name = "plump helmet biscuit"
	desc = "This is a finely-prepared plump helmet biscuit. The ingredients are exceptionally minced plump helmet, and well-minced dwarven wheat flour."
	icon_state = "phelmbiscuit"
	filling_color = "#CFB4C4"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("mushroom" = 4)
	nutriment_amt = 5
	New()
		..()
		if (prob(10))
			name = "exceptional plump helmet biscuit"
			desc = "Microwave is taken by a fey mood! It has cooked an exceptional plump helmet biscuit!"
			reagents.add_reagent("nutriment", 3)
			reagents.add_reagent("tricordrazine", 5)
			bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/chawanmushi
	name = "chawanmushi"
	desc = "A legendary egg custard that makes friends out of enemies. Probably too hot for a cat to eat."
	icon_state = "chawanmushi"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#F0F2E4"
	center_of_mass = list("x"=17, "y"=10)

	New()
		..()
		reagents.add_reagent("protein", 5)
		bitesize = 1
*/

/obj/item/weapon/reagent_containers/food/snacks/beetsoup
	name = "borshch"
	desc = "Delicious beet and tomato soup."
	icon_state = "beetsoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#FAC9FF"
	center_of_mass = list("x"=15, "y"=8)
	nutriment_desc = list("tomato" = 4, "beet" = 4)
	nutriment_amt = 8
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("tomatojuice", 5)
		reagents.add_reagent("imidazoline", 5)
		reagents.add_reagent("water", 15)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/caldoverde
	name = "caldo verde"
	desc = "A typical Portuguese soup, made with cabbages and potatoes."
	icon_state = "caldoverde"
	trash = /obj/item/kitchen/wood_bowl
	filling_color = "#FAC9FF"
	center_of_mass = list("x"=15, "y"=8)
	nutriment_desc = list("cabbage" = 4, "potato" = 2, "olive oil" = 1)
	nutriment_amt = 4
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("water", 15)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/tossedsalad
	name = "tossed salad"
	desc = "A proper salad, basic and simple, with little bits of carrot, tomato and apple intermingled. Vegan!"
	icon_state = "herbsalad"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#76B87F"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("salad" = 2, "tomato" = 2, "carrot" = 2, "apple" = 2)
	nutriment_amt = 8
	New()
		..()
		bitesize = 3
/*
/obj/item/weapon/reagent_containers/food/snacks/validsalad
	name = "valid salad"
	desc = "It's just a salad of questionable 'herbs' with meatballs and fried potato slices. Nothing suspicious about it."
	icon_state = "validsalad"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#76B87F"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("100% real salad")
	nutriment_amt = 6
	New()
		..()
		reagents.add_reagent("protein", 2)
		bitesize = 3
*/

/obj/item/weapon/reagent_containers/food/snacks/appletart
	name = "golden apple streusel tart"
	desc = "A tasty dessert that won't make it through a metal detector."
	icon_state = "gappletart"
	trash = /obj/item/kitchen/plate
	filling_color = "#FFFF00"
	center_of_mass = list("x"=16, "y"=18)
	nutriment_desc = list("apple" = 8)
	nutriment_amt = 8
	New()
		..()
		reagents.add_reagent("gold", 5)
		bitesize = 3

/////////////////////////////////////////////////Sliceable////////////////////////////////////////
// All the food items that can be sliced into smaller bits like Meatbread and Cheesewheels

// sliceable is just an organization type path, it doesn't have any additional code or variables tied to it.

/obj/item/weapon/reagent_containers/food/snacks/sliceable
	w_class = 3 //Whole pizzas and cakes shouldn't fit in a pocket, you can slice them if you want to do that.

/obj/item/weapon/reagent_containers/food/snacks/sliceable/meatbread
	name = "meatbread loaf"
	desc = "The culinary base of every self-respecting eloquen/tg/entleman."
	icon_state = "meatbread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/meatbreadslice
	slices_num = 5
	filling_color = "#FF7575"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	New()
		..()
		reagents.add_reagent("protein", 20)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/meatbreadslice
	name = "meatbread slice"
	desc = "A slice of delicious meatbread."
	icon_state = "meatbreadslice"
	trash = /obj/item/kitchen/plate
	filling_color = "#FF7575"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=13)


/obj/item/weapon/reagent_containers/food/snacks/sliceable/bananabread
	name = "Banana-nut bread"
	desc = "A heavenly and filling treat."
	icon_state = "bananabread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/bananabreadslice
	slices_num = 5
	filling_color = "#EDE5AD"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	New()
		..()
		reagents.add_reagent("banana", 20)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/bananabreadslice
	name = "Banana-nut bread slice"
	desc = "A slice of delicious banana bread."
	icon_state = "bananabreadslice"
	trash = /obj/item/kitchen/plate
	filling_color = "#EDE5AD"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=8)


/obj/item/weapon/reagent_containers/food/snacks/sliceable/carrotcake
	name = "Carrot Cake"
	desc = "A favorite desert of a certain wascally wabbit. Not a lie."
	icon_state = "carrotcake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/carrotcakeslice
	slices_num = 5
	filling_color = "#FFD675"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "carrot" = 15)
	nutriment_amt = 25
	New()
		..()
		reagents.add_reagent("imidazoline", 10)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/carrotcakeslice
	name = "Carrot Cake slice"
	desc = "Carrotty slice of Carrot Cake, carrots are good for your eyes! Also not a lie."
	icon_state = "carrotcake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#FFD675"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesecake
	name = "Cheese Cake"
	desc = "DANGEROUSLY cheesy."
	icon_state = "cheesecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice
	slices_num = 5
	filling_color = "#FAF7AF"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "cream" = 10, "cheese" = 15)
	nutriment_amt = 10
	New()
		..()
		reagents.add_reagent("protein", 15)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice
	name = "Cheese Cake slice"
	desc = "Slice of pure cheestisfaction"
	icon_state = "cheesecake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#FAF7AF"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/plaincake
	name = "Vanilla Cake"
	desc = "A plain cake, not a lie."
	icon_state = "plaincake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/plaincakeslice
	slices_num = 5
	filling_color = "#F7EDD5"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "vanilla" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/plaincakeslice
	name = "Vanilla Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "plaincake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#F7EDD5"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/orangecake
	name = "Orange Cake"
	desc = "A cake with added orange."
	icon_state = "orangecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/orangecakeslice
	slices_num = 5
	filling_color = "#FADA8E"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "orange" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/orangecakeslice
	name = "Orange Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "orangecake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#FADA8E"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/limecake
	name = "Lime Cake"
	desc = "A cake with added lime."
	icon_state = "limecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/limecakeslice
	slices_num = 5
	filling_color = "#CBFA8E"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "lime" = 15)
	nutriment_amt = 20


/obj/item/weapon/reagent_containers/food/snacks/limecakeslice
	name = "Lime Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "limecake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#CBFA8E"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/lemoncake
	name = "Lemon Cake"
	desc = "A cake with added lemon."
	icon_state = "lemoncake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/lemoncakeslice
	slices_num = 5
	filling_color = "#FAFA8E"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "lemon" = 15)
	nutriment_amt = 20


/obj/item/weapon/reagent_containers/food/snacks/lemoncakeslice
	name = "Lemon Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "lemoncake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#FAFA8E"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/chocolatecake
	name = "Chocolate Cake"
	desc = "A cake with added chocolate"
	icon_state = "chocolatecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice
	slices_num = 5
	filling_color = "#805930"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "chocolate" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice
	name = "Chocolate Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "chocolatecake_slice"
	trash = /obj/item/kitchen/plate
	filling_color = "#805930"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel
	name = "Cheese wheel"
	desc = "A big wheel of delcious Cheddar."
	icon_state = "cheesewheel"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/cheesewedge
	slices_num = 5
	filling_color = "#FFF700"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cheese" = 10)
	nutriment_amt = 10
	New()
		..()
		reagents.add_reagent("protein", 10)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/cheesewedge
	name = "Cheese wedge"
	desc = "A wedge of delicious Cheddar. The cheese wheel it was cut from can't have gone far."
	icon_state = "cheesewedge"
	filling_color = "#FFF700"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=10)


/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread
	name = "Bread"
	icon_state = "Some plain old Earthen bread."
	icon_state = "bread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/breadslice
	slices_num = 5
	filling_color = "#FFE396"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 6)
	nutriment_amt = 6
	New()
		..()
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/breadslice
	name = "Bread slice"
	desc = "A slice of home."
	icon_state = "breadslice"
	trash = /obj/item/kitchen/plate
	filling_color = "#D27332"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=4)


/obj/item/weapon/reagent_containers/food/snacks/sliceable/creamcheesebread
	name = "Cream Cheese Bread"
	desc = "Yum yum yum!"
	icon_state = "creamcheesebread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/creamcheesebreadslice
	slices_num = 5
	filling_color = "#FFF896"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 6, "cream" = 3, "cheese" = 3)
	nutriment_amt = 5
	New()
		..()
		reagents.add_reagent("protein", 15)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/creamcheesebreadslice
	name = "Cream Cheese Bread slice"
	desc = "A slice of yum!"
	icon_state = "creamcheesebreadslice"
	trash = /obj/item/kitchen/plate
	filling_color = "#FFF896"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=13)


/obj/item/weapon/reagent_containers/food/snacks/watermelonslice
	name = "Watermelon Slice"
	desc = "A slice of watery goodness."
	icon_state = "watermelonslice"
	filling_color = "#FF3867"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=10)


/obj/item/weapon/reagent_containers/food/snacks/sliceable/applecake
	name = "Apple Cake"
	desc = "A cake centred with Apple"
	icon_state = "applecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/applecakeslice
	slices_num = 5
	filling_color = "#EBF5B8"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "apple" = 15)
	nutriment_amt = 15

/obj/item/weapon/reagent_containers/food/snacks/applecakeslice
	name = "Apple Cake slice"
	desc = "A slice of heavenly cake."
	icon_state = "applecakeslice"
	trash = /obj/item/kitchen/plate
	filling_color = "#EBF5B8"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie
	name = "Pumpkin Pie"
	desc = "A delicious treat for the autumn months."
	icon_state = "pumpkinpie"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pumpkinpieslice
	slices_num = 5
	filling_color = "#F5B951"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("pie" = 5, "cream" = 5, "pumpkin" = 5)
	nutriment_amt = 15

/obj/item/weapon/reagent_containers/food/snacks/pumpkinpieslice
	name = "Pumpkin Pie slice"
	desc = "A slice of pumpkin pie, with whipped cream on top. Perfection."
	icon_state = "pumpkinpieslice"
	trash = /obj/item/kitchen/plate
	filling_color = "#F5B951"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=12)

/obj/item/weapon/reagent_containers/food/snacks/cracker
	name = "Cracker"
	desc = "It's a salted cracker."
	icon_state = "cracker"
	filling_color = "#F5DEB8"
	center_of_mass = list("x"=17, "y"=6)
	nutriment_desc = list("salt" = 1, "cracker" = 2)
	nutriment_amt = 1

///////////////////////////////////////////
// new old food stuff from bs12
///////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/dough
	name = "dough"
	desc = "A piece of dough."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "dough"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("dough" = 3)
	nutriment_amt = 3
	New()
		..()
		reagents.add_reagent("protein", 1)

// Dough + rolling pin = flat dough
/obj/item/weapon/reagent_containers/food/snacks/dough/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/material/kitchen/rollingpin))
		new /obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough(get_turf(src))
		user << "You flatten the dough."
		qdel(src)
	else if (W.sharp || W.edge)
		user << "You make some spaghetti from the dough."
		for (var/v in 1 to pick(2,3))
			new /obj/item/weapon/reagent_containers/food/snacks/spaghetti(get_turf(src))
		qdel(src)

// slicable into 3xdoughslices
/obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough
	name = "flat dough"
	desc = "A flattened dough."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "flat dough"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/doughslice
	slices_num = 3
	center_of_mass = list("x"=16, "y"=16)

	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("nutriment", 3)

/obj/item/weapon/reagent_containers/food/snacks/doughslice
	name = "dough slice"
	desc = "A building block of an impressive dish."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "doughslice"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/spaghetti
	slices_num = 1
	bitesize = 2
	center_of_mass = list("x"=17, "y"=19)
	nutriment_desc = list("dough" = 1)
	nutriment_amt = 1


/obj/item/weapon/reagent_containers/food/snacks/bun
	name = "bun"
	desc = "A base for any self-respecting burger."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "bun"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=12)
	nutriment_desc = list("bun" = 4)
	nutriment_amt = 4


/obj/item/weapon/reagent_containers/food/snacks/bun/attackby(obj/item/weapon/W as obj, mob/user as mob)
	// Bun + meatball = burger
	/*
	if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/meatball))
		new /obj/item/weapon/reagent_containers/food/snacks/monkeyburger(src)
		user << "You make a burger."
		qdel(W)
		qdel(src)

	// Bun + cutlet = hamburger
	else if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/cutlet))
		new /obj/item/weapon/reagent_containers/food/snacks/monkeyburger(src)
		user << "You make a burger."
		qdel(W)
		qdel(src)*/

	// Bun + sausage = hotdog
	if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/sausage))
		new /obj/item/weapon/reagent_containers/food/snacks/hotdog(src)
		user << "You make a hotdog."
		qdel(W)
		qdel(src)
/*
// Burger + cheese wedge = cheeseburger
/obj/item/weapon/reagent_containers/food/snacks/monkeyburger/attackby(obj/item/weapon/reagent_containers/food/snacks/cheesewedge/W as obj, mob/user as mob)
	if (istype(W))// && !istype(src,/obj/item/weapon/reagent_containers/food/snacks/cheesewedge))
		new /obj/item/weapon/reagent_containers/food/snacks/cheeseburger(src)
		user << "You make a cheeseburger."
		qdel(W)
		qdel(src)
		return
	else
		..()*/
/*
// Human Burger + cheese wedge = cheeseburger
/obj/item/weapon/reagent_containers/food/snacks/human/burger/attackby(obj/item/weapon/reagent_containers/food/snacks/cheesewedge/W as obj, mob/user as mob)
	if (istype(W))
		new /obj/item/weapon/reagent_containers/food/snacks/cheeseburger(src)
		user << "You make a cheeseburger."
		qdel(W)
		qdel(src)
		return
	else
		..()
*/
/obj/item/weapon/reagent_containers/food/snacks/taco
	name = "taco"
	desc = "Take a bite!"
	icon_state = "taco"
	bitesize = 3
	center_of_mass = list("x"=21, "y"=12)
	nutriment_desc = list("cheese" = 2,"taco shell" = 2)
	nutriment_amt = 4
	New()
		..()
		reagents.add_reagent("protein", 3)

/obj/item/weapon/reagent_containers/food/snacks/rawcutlet
	name = "raw cutlet"
	desc = "A thin piece of raw meat."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "rawcutlet"
	bitesize = 1
	center_of_mass = list("x"=17, "y"=20)
	raw = TRUE
	var/rotten = FALSE

	New()
		..()
		reagents.add_reagent("protein", 1)
		spawn(2400) //4 minutes
			icon_state = "rottencutlet"
			name = "rotten [name]"
			rotten = TRUE
			reagents.remove_reagent("protein", 1)
			reagents.add_reagent("food_poisoning", 1)
			spawn(3000)
				qdel(src)
/obj/item/weapon/reagent_containers/food/snacks/cutlet
	name = "cutlet"
	desc = "A tasty meat slice."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "cutlet"
	bitesize = 2
	center_of_mass = list("x"=17, "y"=20)

	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/rawmeatball
	name = "raw meatball"
	desc = "A raw meatball."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "rawmeatball"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=15)

	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/hotdog
	name = "hotdog"
	desc = "Unrelated to dogs, maybe."
	icon_state = "hotdog"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=17)

	New()
		..()
		reagents.add_reagent("protein", 6)

/obj/item/weapon/reagent_containers/food/snacks/flatbread
	name = "flatbread"
	desc = "Bland but filling."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "flatbread"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=16)
	nutriment_desc = list("bread" = 3)
	nutriment_amt = 3

// potato + knife = raw sticks
/obj/item/weapon/reagent_containers/food/snacks/grown/potato/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		new /obj/item/weapon/reagent_containers/food/snacks/rawsticks(src)
		user << "You cut the potato."
		qdel(src)
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/rawsticks
	name = "raw potato sticks"
	desc = "Raw fries, not very tasty."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "rawsticks"
	bitesize = 2
	center_of_mass = list("x"=16, "y"=12)
	nutriment_desc = list("raw potato" = 3)
	nutriment_amt = 3