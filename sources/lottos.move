module lottos::lottos {
    use std::bcs;
    use std::signer;
    use std::string::{Self, String};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::string_utils;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::event;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::randomness;
    use aptos_framework::timestamp;

    use lottos::config;
    use lottos::utils;

    const LOTTO_535: vector<u8> = b"Lotto 5/35";
    const MEGA_645: vector<u8> = b"Mega 6/45";
    const POWER_655: vector<u8> = b"Power 6/55";

    const LOTTOS_DOMAIN_SEPARATOR: vector<u8> = b"lottos::lottos";


    /// $0.5 per ticket
    const TICKET_PRICE: u64 = 500000;

    /// Not valid ticket numbers
    const EINVALID_TICKET_NUMBER: u64 = 1;
    /// Ticket does not exist
    const ETICKET_NOT_FOUND: u64 = 2;
    /// Already bought this ticket
    const ETICKET_ALREADY_BOUGHT: u64 = 3;
    /// Cannot buy tickets after draw is closed
    const ECLOSED_DRAW: u64 = 4;
    /// Not open draw
    const ENOT_OPEN_DRAW: u64 = 5;
    /// Cannot claim prize before draw is completed
    const ENOT_COMPLETED_DRAW: u64 = 6;
    /// Not a winning ticket
    const ENOT_WINNER: u64 = 7;
    /// Ticket already claimed
    const EALREADY_CLAIMED: u64 = 8;
    /// First draw cannot be rollover
    const EFIRST_DRAW_ROLLOVER: u64 = 9;

    enum DrawStatus has copy, drop, store {
        Open,
        Completed
    }

    enum ClaimStatus has copy, drop, store {
        Unclaimed,
        Claimed
    }

    enum PrizeTier has copy, drop, store {
        NoWin,
        Consolation,
        Fifth,
        Fourth,
        Third,
        Second,
        First,
        Jackpot,
        Jackpot2  // For Power 6/55 with extra number match
    }

    struct Lottos has key {
        next_draw_id: u64,
        draws: SmartTable<u64, Draw>,
        config: SmartTable<String, GameConfig>
    }

    struct GameConfig has copy, drop, store {
        type: String,
        total_numbers: u64,
        picks_count: u64,
        ticket_price: u64,
        prize_values: SimpleMap<PrizeTier, u64>,
        has_extra_number: bool
    }

    struct Draw has store {
        id: u64,
        type: String,
        status: DrawStatus,
        close_timestamp_secs: u64,
        // Cumulative jackpot pool for this draw, if last draw don't have winner, 50% ticket sold will be added to next draw
        cumulative_jackpot_pool: u64,
        // Cumulative jackpot2 pool for this draw, if last draw don't have winner, 10% ticket sold will be added to next draw
        cumulative_jackpot2_pool: u64,
        winning_numbers: vector<u64>,
        // extra number for Power 6/55
        extra_number: u64,
        num_ticket_sold: u64,
        tickets_sold: SmartTable<String, vector<address>>,
    }

    // draw id + ticket numbers + user address
    struct Ticket has key, store {
        draw_id: u64,
        chosen_numbers: vector<u64>,
        owner: address,
        claim_status: ClaimStatus,
    }

    #[event]
    struct CreateDrawEvent has drop, store {
        draw_id: u64,
        type: String,
        close_timestamp_secs: u64,
    }

    #[event]
    struct BuyTicketEvent has drop, store {
        draw_id: u64,
        user: address,
        ticket: vector<u64>,
    }

    #[event]
    struct ClaimPrizeEvent has drop, store {
        draw_id: u64,
        user: address,
        ticket: vector<u64>,
        prize_tier: PrizeTier,
        prize_amount: u64,
    }

    #[event]
    struct DrawResultEvent has drop, store {
        draw_id: u64,
        winning_numbers: vector<u64>,
        extra_number: u64,
    }

    fun init_module(lottos_signer: &signer) {
        let config = smart_table::new();
        let lotto_prize_values = simple_map::new();
        lotto_prize_values.add(PrizeTier::Consolation, 1 * TICKET_PRICE);
        lotto_prize_values.add(PrizeTier::Fifth, 3 * TICKET_PRICE);
        lotto_prize_values.add(PrizeTier::Fourth, 10 * TICKET_PRICE);
        lotto_prize_values.add(PrizeTier::Third, 50 * TICKET_PRICE);
        lotto_prize_values.add(PrizeTier::Second, 500 * TICKET_PRICE);
        lotto_prize_values.add(PrizeTier::First, 1000 * TICKET_PRICE);
        lotto_prize_values.add(PrizeTier::Jackpot, 600_000 * TICKET_PRICE);
        config.add(string::utf8(LOTTO_535), GameConfig {
            type: string::utf8(LOTTO_535),
            total_numbers: 35,
            picks_count: 5,
            ticket_price: TICKET_PRICE,
            prize_values: lotto_prize_values,
            has_extra_number: true
        });

        let mega_prize_values = simple_map::new();
        mega_prize_values.add(PrizeTier::Third, 3 * TICKET_PRICE);
        mega_prize_values.add(PrizeTier::Second, 30 * TICKET_PRICE);
        mega_prize_values.add(PrizeTier::First, 1000 * TICKET_PRICE);
        mega_prize_values.add(PrizeTier::Jackpot, 1_200_000 * TICKET_PRICE);
        config.add(string::utf8(MEGA_645), GameConfig {
            type: string::utf8(MEGA_645),
            total_numbers: 45,
            picks_count: 6,
            ticket_price: TICKET_PRICE,
            prize_values: mega_prize_values,
            has_extra_number: false
        });

        let power_prize_values = simple_map::new();
        power_prize_values.add(PrizeTier::Third, 5 * TICKET_PRICE);
        power_prize_values.add(PrizeTier::Second, 50 * TICKET_PRICE);
        power_prize_values.add(PrizeTier::First, 4000 * TICKET_PRICE);
        power_prize_values.add(PrizeTier::Jackpot2, 300_000 * TICKET_PRICE);
        power_prize_values.add(PrizeTier::Jackpot, 3_000_000 * TICKET_PRICE);
        config.add(string::utf8(POWER_655), GameConfig {
            type: string::utf8(POWER_655),
            total_numbers: 55,
            picks_count: 6,
            ticket_price: TICKET_PRICE,
            prize_values: power_prize_values,
            has_extra_number: true
        });

        move_to(
            lottos_signer,
            Lottos {
                next_draw_id: 1,
                draws: smart_table::new(),
                config
            }
        )
    }

    // View functions
    #[view]
    public fun get_draw(draw_id: u64): (u64, String, DrawStatus, u64, u64, u64, vector<u64>, u64, u64) acquires Lottos {
        let lottos = &Lottos[@lottos];
        let draw = lottos.draws.borrow(draw_id);
        (
            draw.id,
            draw.type,
            draw.status,
            draw.close_timestamp_secs,
            draw.cumulative_jackpot_pool,
            draw.cumulative_jackpot2_pool,
            draw.winning_numbers,
            draw.extra_number,
            draw.num_ticket_sold
        )
    }

    #[view]
    public fun get_ticket(
        user: address,
        draw_id: u64,
        ticket_numbers: vector<u64>
    ): (u64, vector<u64>, address, ClaimStatus) acquires Ticket {
        let sorted_ticket = string_utils::to_string(&utils::sort(ticket_numbers));
        let ticket_addr = object::create_object_address(
            &user,
            ticket_seed(user, draw_id, sorted_ticket)
        );
        let ticket = &Ticket[ticket_addr];
        (
            ticket.draw_id,
            ticket.chosen_numbers,
            ticket.owner,
            ticket.claim_status
        )
    }

    #[view]
    public fun get_next_draw_id(): u64 acquires Lottos {
        let lottos = &Lottos[@lottos];
        lottos.next_draw_id
    }

    public entry fun buy_tickets(
        user: &signer,
        draw: u64,
        tickets: vector<vector<u64>>,
        payment_fa: Object<Metadata>
    ) acquires Lottos {
        let user_addr = signer::address_of(user);
        let lottos = &mut Lottos[@lottos];
        let draw = lottos.draws.borrow_mut(draw);
        let game_config = lottos.config.borrow(draw.type);

        let now_seconds = timestamp::now_seconds();
        assert!(draw.close_timestamp_secs > now_seconds, ECLOSED_DRAW);
        config::assert_stable_fa(payment_fa);

        dispatchable_fungible_asset::transfer(
            user,
            primary_fungible_store::primary_store(user_addr, payment_fa),
            primary_fungible_store::primary_store(@treasury, payment_fa),
            tickets.length() * game_config.ticket_price
        );

        draw.num_ticket_sold += tickets.length();
        tickets.for_each(|ticket| {
            game_config.assert_valid_ticket(ticket);
            let sorted_ticket = string_utils::to_string(&utils::sort(ticket));

            // if the ticket is already sold, add the user to the list
            if (draw.tickets_sold.contains(sorted_ticket)) {
                let users = draw.tickets_sold.borrow_mut(sorted_ticket);
                assert!(!users.contains(&user_addr), ETICKET_ALREADY_BOUGHT);
                users.push_back(user_addr);
            } else {
                draw.tickets_sold.add(sorted_ticket, vector[user_addr]);
            };

            let ticket_constructor_ref = &object::create_named_object(
                user,
                ticket_seed(user_addr, draw.id, sorted_ticket)
            );
            let ticket_signer = &object::generate_signer(ticket_constructor_ref);
            move_to(
                ticket_signer,
                Ticket {
                    draw_id: draw.id,
                    chosen_numbers: ticket,
                    owner: user_addr,
                    claim_status: ClaimStatus::Unclaimed
                }
            );

            event::emit(BuyTicketEvent {
                draw_id: draw.id,
                user: user_addr,
                ticket
            });
        });
    }

    public entry fun claim_prize(
        user: &signer,
        treasury: &signer,
        draw_id: u64,
        ticket_numbers: vector<u64>,
        payment_fa: Object<Metadata>
    ) acquires Lottos, Ticket {
        let user_addr = signer::address_of(user);
        let lottos = &Lottos[@lottos];
        let draw = lottos.draws.borrow(draw_id);

        assert!(draw.status == DrawStatus::Completed, ENOT_COMPLETED_DRAW);

        // Check what prize tier this ticket wins
        let prize_tier = draw.compare_draw_result(ticket_numbers);

        // Only process if there's a winning prize
        assert!(prize_tier != PrizeTier::NoWin, ENOT_WINNER);

        // Verify ticket ownership and claim status
        let sorted_ticket = string_utils::to_string(&utils::sort(ticket_numbers));
        let ticket_addr = object::create_object_address(
            &user_addr,
            ticket_seed(user_addr, draw_id, sorted_ticket)
        );
        assert!(exists<Ticket>(ticket_addr), ETICKET_NOT_FOUND);
        let ticket = &mut Ticket[ticket_addr];
        assert!(ticket.claim_status == ClaimStatus::Unclaimed, EALREADY_CLAIMED);

        // Calculate prize amount based on tier and prize pool
        let game_config = lottos.config.borrow(draw.type);
        let prize_amount = *game_config.prize_values.borrow(&prize_tier);

        // If prize is Jackpot, wil check number of winners and split the prize
        if (prize_tier == PrizeTier::Jackpot) {
            prize_amount += draw.cumulative_jackpot_pool;
            let num_winners = draw.tickets_sold.borrow(sorted_ticket).length();
            prize_amount /= num_winners;
        };

        if (prize_tier == PrizeTier::Jackpot2) {
            prize_amount += draw.cumulative_jackpot_pool;
            let num_winners = draw.tickets_sold.borrow(sorted_ticket).length();
            // TODO: Split prize amount
            prize_amount /= num_winners;
        };

        // Transfer prize to winner
        dispatchable_fungible_asset::transfer(
            treasury,
            primary_fungible_store::primary_store(signer::address_of(treasury), payment_fa),
            primary_fungible_store::ensure_primary_store_exists(user_addr, payment_fa),
            prize_amount
        );

        ticket.claim_status = ClaimStatus::Claimed;

        event::emit(ClaimPrizeEvent {
            draw_id,
            user: user_addr,
            ticket: ticket.chosen_numbers,
            prize_tier,
            prize_amount
        });
    }

    public entry fun create_draw(
        admin: &signer,
        type: String,
        close_timestamp_secs: u64,
    ) acquires Lottos {
        config::assert_admin(admin);

        let lottos = &mut Lottos[@lottos];
        let draw_id = lottos.next_draw_id;
        let draw = Draw {
            id: draw_id,
            type,
            status: DrawStatus::Open,
            close_timestamp_secs,
            cumulative_jackpot_pool: 0,
            cumulative_jackpot2_pool: 0,
            winning_numbers: vector[],
            extra_number: 0,
            num_ticket_sold: 0,
            tickets_sold: smart_table::new()
        };

        lottos.draws.add(draw_id, draw);
        lottos.next_draw_id = draw_id + 1;

        event::emit(CreateDrawEvent {
            draw_id,
            type,
            close_timestamp_secs
        });
    }

    #[randomness]
    entry fun draws(admin: &signer, draw_id: u64) acquires Lottos {
        config::assert_admin(admin);

        let lottos = &mut Lottos[@lottos];
        let draw = lottos.draws.borrow(draw_id);
        assert!(draw.status == DrawStatus::Open, ENOT_OPEN_DRAW);
        let game_config = lottos.config.borrow(draw.type);

        let cumulative_jackpot_pool = 0;
        let cumulative_jackpot2_pool = 0;
        if (draw.id > 1) {
            let from_draw_id = draw.id - 1;
            loop {
                let from_draw = lottos.draws.borrow(from_draw_id);
                if (from_draw.type == draw.type || from_draw_id == 0) {
                    break;
                };
                from_draw_id -= 1;
            };
            if (from_draw_id != 0) {
                let from_draw = lottos.draws.borrow(from_draw_id);
                (cumulative_jackpot_pool, cumulative_jackpot2_pool) = rollover_jackpot(draw, from_draw, game_config);
            };
        };

        let draw = lottos.draws.borrow_mut(draw_id);

        let winning_numbers = vector[];
        let extra_number = 0;
        for (i in 0..game_config.picks_count) {
            let number = randomness::u64_range(1, game_config.total_numbers + 1);
            while (winning_numbers.contains(&number)) {
                number = randomness::u64_range(1, game_config.total_numbers + 1);
            };
            winning_numbers.push_back(number);
        };

        if (game_config.has_extra_number) {
            extra_number = randomness::u64_range(1, game_config.total_numbers + 1);
            while (winning_numbers.contains(&extra_number)) {
                extra_number = randomness::u64_range(1, game_config.total_numbers + 1);
            };
        };

        draw.status = DrawStatus::Completed;
        draw.winning_numbers = winning_numbers;
        draw.extra_number = extra_number;
        draw.cumulative_jackpot_pool = cumulative_jackpot_pool;
        draw.cumulative_jackpot2_pool = cumulative_jackpot2_pool;

        event::emit(DrawResultEvent {
            draw_id,
            winning_numbers,
            extra_number
        });
    }

    fun assert_valid_ticket(self: &GameConfig, ticket: vector<u64>) {
        // Check correct number of picks
        assert!(ticket.length() == self.picks_count, EINVALID_TICKET_NUMBER);

        let checked = vector[];
        ticket.for_each(|number| {
            // check if number is in range (1-based numbering)
            assert!(number > 0 && number <= self.total_numbers, EINVALID_TICKET_NUMBER);
            // check if number is unique
            assert!(!checked.contains(&number), EINVALID_TICKET_NUMBER);
            checked.push_back(number);
        });
    }

    fun ticket_seed(user_addr: address, draw_id: u64, number: String): vector<u8> {
        let seed = vector[];
        seed.append(LOTTOS_DOMAIN_SEPARATOR);
        seed.append(bcs::to_bytes(&user_addr));
        seed.append(bcs::to_bytes(&draw_id));
        seed.append(*number.bytes());
        seed
    }

    /// Check what prize tier a ticket wins based on number matches
    /// Returns PrizeTier enum indicating the level of prize won
    fun compare_draw_result(self: &Draw, ticket: vector<u64>): PrizeTier {
        let sorted_ticket = utils::sort(ticket);
        let sorted_winning = utils::sort(self.winning_numbers);

        // Count matching numbers
        let matches = 0;
        let i = 0;
        while (i < sorted_ticket.length()) {
            if (sorted_winning.contains(&sorted_ticket[i])) {
                matches += 1;
            };
            i += 1;
        };

        // Check extra number match for Power 6/55
        let extra_match = (ticket.contains(&self.extra_number) && self.extra_number != 0);

        // Determine prize tier based on game type and matches
        if (self.type == string::utf8(LOTTO_535)) {
            // Lotto 5/35: 5 number + extra number
            if (matches == 5 && extra_match) PrizeTier::Jackpot
            else if (matches == 5) PrizeTier::First
            else if (matches == 4 && extra_match) PrizeTier::Second
            else if (matches == 4) PrizeTier::Third
            else if (matches == 3 && extra_match) PrizeTier::Fourth
            else if (matches == 3) PrizeTier::Fifth
            else if ((matches == 1 || matches == 2) && extra_match) PrizeTier::Consolation
            else PrizeTier::NoWin
        } else if (self.type == string::utf8(MEGA_645)) {
            // Mega 6/45: 6 numbers, no extra
            if (matches == 6) PrizeTier::Jackpot
            else if (matches == 5) PrizeTier::First
            else if (matches == 4) PrizeTier::Second
            else if (matches == 3) PrizeTier::Third
            else PrizeTier::NoWin
        } else {
            // Power 6/55: 6 numbers + extra number
            if (matches == 6) PrizeTier::Jackpot
            else if (matches == 5 && extra_match) PrizeTier::Jackpot2  // Special jackpot with extra
            else if (matches == 5) PrizeTier::First
            else if (matches == 4) PrizeTier::Second
            else if (matches == 3) PrizeTier::Third
            else PrizeTier::NoWin
        }
    }

    fun rollover_jackpot(
        to_draw: &Draw,
        from_draw: &Draw,
        game_config: &GameConfig
    ): (u64, u64) {
        let draw_type = to_draw.type;


        // Verify from_draw is completed
        assert!(from_draw.status == DrawStatus::Completed, ENOT_COMPLETED_DRAW);
        let from_draw_result = from_draw.winning_numbers;
        let has_jackpot_winner = from_draw.tickets_sold.contains(
            string_utils::to_string(&utils::sort(from_draw_result))
        );

        let has_jackpot2_winner = false;
        if (to_draw.type == string::utf8(POWER_655)) {
            let numbers_win_jackpot2 = utils::generate_5_from_6(from_draw_result);
            let numbers_win_jackpot2_string = numbers_win_jackpot2.map(|number| {
                number.push_back(from_draw.extra_number);
                string_utils::to_string(&utils::sort(number))
            });
            numbers_win_jackpot2_string.for_each(|number| {
                if (from_draw.tickets_sold.contains(number)) {
                    has_jackpot2_winner = true;
                };
            });
        };

        let num_ticket_sold = from_draw.num_ticket_sold;
        let ticket_price = game_config.ticket_price;

        let cumulative_jackpot_pool = 0;
        let cumulative_jackpot2_pool = 0;
        if (!has_jackpot_winner) {
            cumulative_jackpot_pool = to_draw.cumulative_jackpot_pool + (num_ticket_sold / 2) * ticket_price;
        };

        if (!has_jackpot2_winner) {
            cumulative_jackpot2_pool = to_draw.cumulative_jackpot2_pool + (num_ticket_sold / 10) * ticket_price;
        };

        (
            cumulative_jackpot_pool,
            cumulative_jackpot2_pool
        )
    }
}
