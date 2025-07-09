/// # Lottos - Decentralized Lottery System
///
/// A comprehensive lottery smart contract supporting three game types:
/// - **Lotto 5/35**: Pick 5 numbers from 1-35 plus an extra number
/// - **Mega 6/45**: Pick 6 numbers from 1-45 (no extra number)
/// - **Power 6/55**: Pick 6 numbers from 1-55 plus an extra number
///
/// ## Key Features
/// - **Secure Random Number Generation**: Uses Aptos randomness framework
/// - **Jackpot Rollover**: Accumulates prizes when no winners
/// - **Multiple Prize Tiers**: From consolation to jackpot prizes
/// - **Treasury Control**: Multi-signature prize distribution
/// - **Ticket Ownership**: NFT-based ticket representation
///
/// ## Security Model
/// - Admin-controlled draw creation and execution
/// - Treasury signature required for prize claims
/// - Atomic ticket purchasing with duplicate prevention
/// - Move resource model ensures transaction safety
///
/// ## Prize Distribution
/// - **Jackpot**: 50% of ticket sales + rollover accumulation
/// - **Jackpot2**: 10% of ticket sales + rollover (Power 6/55 only)
/// - **Fixed Tiers**: Predetermined multipliers of ticket price
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

    // ==================== GAME TYPE CONSTANTS ====================
    
    /// Lotto 5/35 game identifier: Pick 5 numbers from 1-35 plus extra number
    const LOTTO_535: vector<u8> = b"Lotto 5/35";
    
    /// Mega 6/45 game identifier: Pick 6 numbers from 1-45 (no extra number)
    const MEGA_645: vector<u8> = b"Mega 6/45";
    
    /// Power 6/55 game identifier: Pick 6 numbers from 1-55 plus extra number
    const POWER_655: vector<u8> = b"Power 6/55";

    /// Domain separator for ticket seed generation to prevent cross-domain attacks
    const LOTTOS_DOMAIN_SEPARATOR: vector<u8> = b"lottos::lottos";

    // ==================== PRICING CONSTANTS ====================
    
    /// Fixed price per lottery ticket: $0.50 USD (in microunits: 500,000 = $0.50)
    /// All game types use the same ticket price for consistency
    const TICKET_PRICE: u64 = 500000;

    // ==================== ERROR CODES ====================
    
    // Ticket validation errors (1-3)
    /// Ticket validation failed: Invalid number count, out-of-range numbers, or duplicates
    const EINVALID_TICKET_NUMBER: u64 = 1;
    /// Ticket object not found: User hasn't purchased this ticket combination
    const ETICKET_NOT_FOUND: u64 = 2;
    /// Duplicate ticket purchase: User already owns this number combination for this draw
    const ETICKET_ALREADY_BOUGHT: u64 = 3;
    
    // Draw state errors (4-7) 
    /// Draw state error: Attempted operation on non-open draw
    const ENOT_OPEN_DRAW: u64 = 4;
    /// Draw closed: Cannot purchase tickets after closing timestamp
    const ECLOSED_DRAW: u64 = 5;
    /// Premature draw execution: Closing time has not been reached yet
    const ENOT_CLOSE_DRAW_TIME: u64 = 6;
    /// Prize claim failed: Draw must be completed before claiming prizes
    const ENOT_COMPLETED_DRAW: u64 = 7;
    
    // Prize claiming errors (8-9)
    /// No prize available: Ticket did not match winning combination
    const ENOT_WINNER: u64 = 8;
    /// Prize already claimed: This ticket has been redeemed
    const EALREADY_CLAIMED: u64 = 9;
    
    // System errors (10)
    /// Rollover logic error: First draw cannot inherit previous jackpots
    const EFIRST_DRAW_ROLLOVER: u64 = 10;

    // ==================== ENUMS ====================
    
    /// Current state of a lottery draw
    enum DrawStatus has copy, drop, store {
        /// Draw is accepting ticket purchases
        Open,
        /// Draw has been executed and winning numbers determined
        Completed
    }

    /// Prize redemption status for individual tickets
    enum ClaimStatus has copy, drop, store {
        /// Prize has not been claimed yet
        Unclaimed,
        /// Prize has been successfully claimed and paid out
        Claimed
    }

    /// Prize tier levels with different payout amounts
    /// Higher tiers require more number matches
    enum PrizeTier has copy, drop, store {
        /// No matching numbers - no prize
        NoWin,
        /// Lowest prize tier (1-2 matches + extra for Lotto 5/35)
        Consolation,
        /// Fifth place prize (3 matches for Lotto 5/35)
        Fifth,
        /// Fourth place prize (3 matches + extra for Lotto 5/35)
        Fourth,
        /// Third place prize (4 matches or 3 matches for Mega 6/45)
        Third,
        /// Second place prize (4 matches + extra or 4 matches for Mega 6/45)
        Second,
        /// First place prize (5 matches or 5 matches for Mega 6/45)
        First,
        /// Main jackpot (5/6 matches + extra or 6 matches)
        Jackpot,
        /// Special jackpot for Power 6/55 (5 matches + extra number)
        Jackpot2
    }

    // ==================== CORE STRUCTS ====================
    
    /// Main lottery contract state stored at module address
    /// Contains all active draws and game configurations
    struct Lottos has key {
        /// Auto-incrementing ID for next draw (starts at 1)
        next_draw_id: u64,
        /// All lottery draws indexed by draw ID
        draws: SmartTable<u64, Draw>,
        /// Game type configurations (Lotto 5/35, Mega 6/45, Power 6/55)
        config: SmartTable<String, GameConfig>
    }

    /// Configuration for each lottery game type
    /// Defines rules, prize structure, and validation parameters
    struct GameConfig has copy, drop, store {
        /// Game type identifier (e.g., "Lotto 5/35")
        type: String,
        /// Maximum number in the range (35, 45, or 55)
        total_numbers: u64,
        /// How many numbers player must pick (5 or 6)
        picks_count: u64,
        /// Cost per ticket in microunits
        ticket_price: u64,
        /// Prize amounts for each tier as multiples of ticket price
        prize_values: SimpleMap<PrizeTier, u64>,
        /// Whether this game includes an extra number draw
        has_extra_number: bool
    }

    /// Individual lottery draw instance
    /// Contains all state for a specific draw including tickets and results
    struct Draw has store {
        /// Unique draw identifier
        id: u64,
        /// Game type for this draw
        type: String,
        /// Current draw state (Open/Completed)
        status: DrawStatus,
        /// Unix timestamp when ticket sales close
        close_timestamp_secs: u64,
        /// Accumulated main jackpot from previous draws without winners
        /// Fed by 50% of ticket sales when no jackpot winner
        cumulative_jackpot_pool: u64,
        /// Accumulated secondary jackpot for Power 6/55 game type
        /// Fed by 10% of ticket sales when no jackpot2 winner
        cumulative_jackpot2_pool: u64,
        /// Winning numbers drawn for this round (empty until completed)
        winning_numbers: vector<u64>,
        /// Extra number for games that support it (0 if not used)
        extra_number: u64,
        /// Total number of tickets sold for this draw
        num_ticket_sold: u64,
        /// Map of sorted ticket numbers to list of buyers
        /// Key: stringified sorted numbers, Value: addresses that bought it
        tickets_sold: SmartTable<String, vector<address>>,
    }

    /// Individual lottery ticket NFT
    /// Represents ownership of specific number combination for a draw
    struct Ticket has key, store {
        /// Which draw this ticket is for
        draw_id: u64,
        /// Player's chosen numbers (unsorted as picked)
        chosen_numbers: vector<u64>,
        /// Address that owns this ticket
        owner: address,
        /// Whether prize has been claimed
        claim_status: ClaimStatus,
    }

    // ==================== EVENTS ====================
    
    /// Emitted when admin creates a new lottery draw
    #[event]
    struct CreateDrawEvent has drop, store {
        /// ID of the newly created draw
        draw_id: u64,
        /// Game type (Lotto 5/35, Mega 6/45, or Power 6/55)
        type: String,
        /// Unix timestamp when ticket sales close
        close_timestamp_secs: u64,
    }

    /// Emitted when user purchases a lottery ticket
    #[event]
    struct BuyTicketEvent has drop, store {
        /// Which draw the ticket is for
        draw_id: u64,
        /// Address that purchased the ticket
        user: address,
        /// Numbers chosen by the user
        ticket: vector<u64>,
    }

    /// Emitted when user successfully claims a prize
    #[event]
    struct ClaimPrizeEvent has drop, store {
        /// Draw ID where prize was won
        draw_id: u64,
        /// Address that claimed the prize
        user: address,
        /// Winning ticket numbers
        ticket: vector<u64>,
        /// Prize tier achieved
        prize_tier: PrizeTier,
        /// Amount paid out in microunits
        prize_amount: u64,
    }

    /// Emitted when draw is executed and winning numbers determined
    #[event]
    struct DrawResultEvent has drop, store {
        /// Draw that was executed
        draw_id: u64,
        /// Main winning numbers drawn
        winning_numbers: vector<u64>,
        /// Extra number (0 if game type doesn't use it)
        extra_number: u64,
    }

    // ==================== MODULE INITIALIZATION ====================
    
    /// Initialize the lottery module with game configurations and prize structures
    /// Called automatically when the module is published
    ///
    /// Sets up three lottery game types with their respective rules:
    /// - Lotto 5/35: 5 numbers + extra, 7 prize tiers
    /// - Mega 6/45: 6 numbers only, 4 prize tiers
    /// - Power 6/55: 6 numbers + extra, 5 prize tiers
    ///
    /// # Parameters
    /// * `lottos_signer` - The module publisher's signer
    ///
    /// # Aborts
    /// * Never - initialization is deterministic
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

    // ==================== VIEW FUNCTIONS ====================
    
    /// Retrieve complete information about a specific lottery draw
    ///
    /// # Parameters
    /// * `draw_id` - Unique identifier of the draw to query
    ///
    /// # Returns
    /// Tuple containing all draw information:
    /// * `u64` - Draw ID
    /// * `String` - Game type (Lotto 5/35, Mega 6/45, Power 6/55)
    /// * `DrawStatus` - Current status (Open/Completed)
    /// * `u64` - Closing timestamp in seconds
    /// * `u64` - Accumulated main jackpot pool
    /// * `u64` - Accumulated secondary jackpot pool
    /// * `vector<u64>` - Winning numbers (empty if not drawn yet)
    /// * `u64` - Extra number (0 if not applicable)
    /// * `u64` - Total tickets sold
    ///
    /// # Aborts
    /// * If draw_id doesn't exist
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

    /// Retrieve information about a specific lottery ticket
    ///
    /// # Parameters
    /// * `user` - Address that owns the ticket
    /// * `draw_id` - Draw the ticket belongs to
    /// * `ticket_numbers` - Numbers on the ticket (order doesn't matter)
    ///
    /// # Returns
    /// Tuple containing ticket information:
    /// * `u64` - Draw ID this ticket is for
    /// * `vector<u64>` - Chosen numbers as originally picked
    /// * `address` - Owner of the ticket
    /// * `ClaimStatus` - Whether prize has been claimed
    ///
    /// # Aborts
    /// * If ticket doesn't exist for this user/draw/numbers combination
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

    /// Get the next draw ID that will be assigned
    /// Useful for frontend to know what draw ID to expect next
    ///
    /// # Returns
    /// * `u64` - Next draw ID (current highest + 1)
    ///
    /// # Aborts
    /// * Never
    #[view]
    public fun get_next_draw_id(): u64 acquires Lottos {
        let lottos = &Lottos[@lottos];
        lottos.next_draw_id
    }

    // ==================== ENTRY FUNCTIONS ====================
    
    /// Purchase one or more lottery tickets for a specific draw
    ///
    /// Each ticket is represented as an NFT object owned by the user.
    /// Payment is taken upfront for all tickets in the batch.
    /// Numbers are validated according to the game type rules.
    ///
    /// # Parameters
    /// * `user` - Signer purchasing the tickets
    /// * `draw` - Draw ID to purchase tickets for
    /// * `tickets` - Vector of number combinations, each representing one ticket
    /// * `payment_fa` - Fungible asset object to pay with (must be whitelisted)
    ///
    /// # Behavior
    /// - Validates draw is still open for ticket sales
    /// - Checks payment asset is accepted by the system
    /// - Transfers total payment to treasury upfront
    /// - Creates individual Ticket NFT for each number combination
    /// - Prevents duplicate purchases of same numbers by same user
    /// - Emits BuyTicketEvent for each ticket purchased
    ///
    /// # Aborts
    /// * `ECLOSED_DRAW` - If draw closing time has passed
    /// * `EINVALID_TICKET_NUMBER` - If any ticket has invalid numbers
    /// * `ETICKET_ALREADY_BOUGHT` - If user already owns this number combination
    /// * `ENOT_ACCEPTED_FA` - If payment asset is not whitelisted
    /// * If insufficient balance for total payment
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

        assert!(draw.close_timestamp_secs > timestamp::now_seconds(), ECLOSED_DRAW);
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

    /// Claim prize for a winning lottery ticket
    ///
    /// Requires both user and treasury signatures for security.
    /// Calculates prize amount based on tier and jackpot accumulation.
    /// For jackpot tiers, prize is split among all winners.
    ///
    /// # Parameters
    /// * `user` - Signer who owns the winning ticket
    /// * `treasury` - Treasury signer authorizing the payout
    /// * `draw_id` - Draw where the ticket won
    /// * `ticket_numbers` - Winning number combination
    /// * `payment_fa` - Asset to pay prize in (same as ticket purchase)
    ///
    /// # Behavior
    /// - Verifies draw is completed and results available
    /// - Calculates prize tier by comparing ticket to winning numbers
    /// - Validates user owns this ticket and hasn't claimed yet
    /// - For jackpots: adds rollover pool and splits among winners
    /// - Transfers prize from treasury to user
    /// - Marks ticket as claimed to prevent double-spending
    /// - Emits ClaimPrizeEvent with details
    ///
    /// # Prize Calculation
    /// - Fixed tiers: Base amount from game config
    /// - Jackpot: Base + accumulated pool / number of winners
    /// - Jackpot2: Base + accumulated jackpot2 pool / number of winners
    ///
    /// # Aborts
    /// * `ENOT_COMPLETED_DRAW` - If draw hasn't been executed yet
    /// * `ENOT_WINNER` - If ticket doesn't match winning numbers
    /// * `ETICKET_NOT_FOUND` - If user doesn't own this ticket
    /// * `EALREADY_CLAIMED` - If prize was already claimed
    /// * If treasury has insufficient balance for payout
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
            prize_amount += draw.cumulative_jackpot2_pool;
            let ticket_win_jackpot2 = list_ticket_win_jackpot2(
                draw.winning_numbers,
                draw.extra_number
            );

            let num_user_win = 0;
            ticket_win_jackpot2.for_each(|ticket| {
                if (draw.tickets_sold.contains(ticket)) {
                    num_user_win += draw.tickets_sold.borrow(ticket).length();
                };
            });

            prize_amount /= num_user_win;
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

    /// Create a new lottery draw for a specific game type
    ///
    /// Only authorized admins can create draws. Each draw has a unique
    /// auto-incrementing ID and starts in Open status.
    ///
    /// # Parameters
    /// * `admin` - Admin signer authorized to create draws
    /// * `type` - Game type string (must match configured types)
    /// * `close_timestamp_secs` - Unix timestamp when ticket sales close
    ///
    /// # Behavior
    /// - Validates admin authorization
    /// - Creates new draw with auto-incremented ID
    /// - Initializes empty state (no tickets, no winning numbers)
    /// - Sets jackpot pools to zero (will be calculated during draw)
    /// - Emits CreateDrawEvent with draw details
    ///
    /// # Requirements
    /// - Admin must be authorized in config module
    /// - Game type should match one of: "Lotto 5/35", "Mega 6/45", "Power 6/55"
    /// - Close timestamp should be in the future (not enforced here)
    ///
    /// # Aborts
    /// * `EUNAUTHORIZED` - If signer is not an authorized admin
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

    /// Execute a lottery draw by generating random winning numbers
    ///
    /// This function uses Aptos native randomness to generate winning numbers.
    /// It also calculates jackpot rollovers from previous draws and finalizes
    /// the draw state. Can only be called after the draw's closing time.
    ///
    /// # Parameters
    /// * `admin` - Admin signer authorized to execute draws
    /// * `draw_id` - ID of the draw to execute
    ///
    /// # Behavior
    /// - Validates admin authorization and draw state
    /// - Checks that closing time has passed
    /// - Looks up previous draw of same type for rollover calculation
    /// - Generates unique random numbers for main draw
    /// - Generates extra number if required by game type
    /// - Calculates and sets jackpot accumulation from previous draws
    /// - Updates draw status to Completed
    /// - Emits DrawResultEvent with winning numbers
    ///
    /// # Randomness
    /// - Uses Aptos randomness framework for cryptographic security
    /// - Ensures all numbers are unique within the draw
    /// - Extra number is unique from main numbers
    /// - Numbers are in range [1, total_numbers] for the game type
    ///
    /// # Rollover Logic
    /// - If previous draw had no jackpot winner: adds 50% of ticket sales
    /// - If previous draw had no jackpot2 winner: adds 10% of ticket sales
    /// - Only applies to draws of the same game type
    ///
    /// # Aborts
    /// * `EUNAUTHORIZED` - If signer is not an authorized admin
    /// * `ENOT_OPEN_DRAW` - If draw is not in Open status
    /// * `ENOT_CLOSE_DRAW_TIME` - If closing time hasn't been reached
    #[randomness]
    entry fun draws(admin: &signer, draw_id: u64) acquires Lottos {
        config::assert_admin(admin);

        let lottos = &mut Lottos[@lottos];
        let draw = lottos.draws.borrow(draw_id);
        assert!(draw.status == DrawStatus::Open, ENOT_OPEN_DRAW);
        assert!(draw.close_timestamp_secs < timestamp::now_seconds(), ENOT_CLOSE_DRAW_TIME);
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

    // ==================== HELPER FUNCTIONS ====================
    
    /// Validate a lottery ticket according to game rules
    ///
    /// Ensures ticket has correct number count, all numbers are in valid range,
    /// and all numbers are unique (no duplicates).
    ///
    /// # Parameters
    /// * `self` - Game configuration defining validation rules
    /// * `ticket` - Vector of numbers chosen by user
    ///
    /// # Validation Rules
    /// - Exact number of picks as required by game type
    /// - All numbers in range [1, total_numbers]
    /// - No duplicate numbers within the ticket
    ///
    /// # Aborts
    /// * `EINVALID_TICKET_NUMBER` - If any validation rule fails
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

    /// Generate unique seed for ticket object address creation
    ///
    /// Creates a deterministic seed that uniquely identifies each ticket.
    /// Uses domain separation to prevent cross-module collisions.
    ///
    /// # Parameters
    /// * `user_addr` - Address of the ticket purchaser
    /// * `draw_id` - Draw the ticket belongs to
    /// * `number` - Stringified sorted ticket numbers
    ///
    /// # Returns
    /// * `vector<u8>` - Unique seed for object address generation
    ///
    /// # Security
    /// - Domain separator prevents cross-module attacks
    /// - All parameters contribute to uniqueness
    /// - Same inputs always produce same seed (deterministic)
    fun ticket_seed(user_addr: address, draw_id: u64, number: String): vector<u8> {
        let seed = vector[];
        seed.append(LOTTOS_DOMAIN_SEPARATOR);
        seed.append(bcs::to_bytes(&user_addr));
        seed.append(bcs::to_bytes(&draw_id));
        seed.append(*number.bytes());
        seed
    }

    /// Determine prize tier for a ticket by comparing against winning numbers
    ///
    /// Compares user's chosen numbers with the draw's winning numbers to
    /// determine what prize tier (if any) the ticket qualifies for.
    /// Rules vary by game type and include extra number matching.
    ///
    /// # Parameters
    /// * `self` - Draw containing winning numbers and game type
    /// * `ticket` - User's chosen numbers to check
    ///
    /// # Returns
    /// * `PrizeTier` - Prize level won, or NoWin if no matches
    ///
    /// # Game Type Rules
    /// ## Lotto 5/35 (5 numbers + extra)
    /// - Jackpot: 5 matches + extra
    /// - First: 5 matches
    /// - Second: 4 matches + extra
    /// - Third: 4 matches
    /// - Fourth: 3 matches + extra
    /// - Fifth: 3 matches
    /// - Consolation: 1-2 matches + extra
    ///
    /// ## Mega 6/45 (6 numbers only)
    /// - Jackpot: 6 matches
    /// - First: 5 matches
    /// - Second: 4 matches
    /// - Third: 3 matches
    ///
    /// ## Power 6/55 (6 numbers + extra)
    /// - Jackpot: 6 matches
    /// - Jackpot2: 5 matches + extra
    /// - First: 5 matches
    /// - Second: 4 matches
    /// - Third: 3 matches
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

    /// Calculate jackpot rollover amounts from previous draw
    ///
    /// When a draw has no winners for jackpot tiers, a portion of ticket sales
    /// rolls over to the next draw of the same game type. This creates
    /// accumulating jackpots that grow until someone wins.
    ///
    /// # Parameters
    /// * `to_draw` - Current draw that will receive rollover funds
    /// * `from_draw` - Previous draw to check for winners and calculate rollover
    /// * `game_config` - Game configuration for ticket price and rules
    ///
    /// # Returns
    /// * `(u64, u64)` - Tuple of (main_jackpot_rollover, jackpot2_rollover)
    ///
    /// # Rollover Rules
    /// - **Main Jackpot**: If no winner, add 50% of previous draw's ticket sales
    /// - **Jackpot2** (Power 6/55 only): If no winner, add 10% of ticket sales
    /// - Only applies to same game type (Lotto to Lotto, etc.)
    /// - Previous draw must be completed
    ///
    /// # Winner Detection
    /// - Main jackpot: Someone bought exact winning number combination
    /// - Jackpot2: Someone bought 5-of-6 + extra number combination
    ///
    /// # Aborts
    /// * `ENOT_COMPLETED_DRAW` - If from_draw is not completed
    fun rollover_jackpot(
        to_draw: &Draw,
        from_draw: &Draw,
        game_config: &GameConfig
    ): (u64, u64) {
        // Verify from_draw is completed
        assert!(from_draw.status == DrawStatus::Completed, ENOT_COMPLETED_DRAW);
        let from_draw_result = from_draw.winning_numbers;
        let has_jackpot_winner = from_draw.tickets_sold.contains(
            string_utils::to_string(&utils::sort(from_draw_result))
        );

        let has_jackpot2_winner = false;
        if (to_draw.type == string::utf8(POWER_655)) {
            let numbers_win_jackpot2 = list_ticket_win_jackpot2(
                from_draw_result,
                from_draw.extra_number
            );
            numbers_win_jackpot2.for_each(|number| {
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
            cumulative_jackpot_pool = from_draw.cumulative_jackpot_pool + (num_ticket_sold * ticket_price) / 2;
        };

        if (!has_jackpot2_winner) {
            cumulative_jackpot2_pool = from_draw.cumulative_jackpot2_pool + (num_ticket_sold * ticket_price) / 10;
        };

        (
            cumulative_jackpot_pool,
            cumulative_jackpot2_pool
        )
    }

    /// Generate all possible Jackpot2 winning combinations for Power 6/55
    ///
    /// For Power 6/55, Jackpot2 is won by matching 5 out of 6 main numbers
    /// plus the extra number. This function generates all possible 5-number
    /// combinations from the 6 winning numbers, each combined with the extra.
    ///
    /// # Parameters
    /// * `winning_numbers` - The 6 main winning numbers drawn
    /// * `extra_number` - The extra number drawn
    ///
    /// # Returns
    /// * `vector<String>` - All possible ticket combinations that win Jackpot2
    ///   Each string represents a sorted ticket (5 numbers + extra)
    ///
    /// # Example
    /// If winning numbers are [1,2,3,4,5,6] and extra is 7, generates:
    /// - "1,2,3,4,5,7" (missing 6)
    /// - "1,2,3,4,6,7" (missing 5)
    /// - "1,2,3,5,6,7" (missing 4)
    /// - "1,2,4,5,6,7" (missing 3)
    /// - "1,3,4,5,6,7" (missing 2)
    /// - "2,3,4,5,6,7" (missing 1)
    ///
    /// # Usage
    /// Used in rollover calculation to detect if anyone won Jackpot2
    /// in the previous draw.
    fun list_ticket_win_jackpot2(
        winning_numbers: vector<u64>,
        extra_number: u64
    ): vector<String> {
        let numbers_win_jackpot2 = utils::generate_5_from_6(winning_numbers);
        let numbers_win_jackpot2_string = numbers_win_jackpot2.map(|number| {
            number.push_back(extra_number);
            string_utils::to_string(&utils::sort(number))
        });

        numbers_win_jackpot2_string
    }
}
