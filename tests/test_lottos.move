#[test_only]
module lottos::test_lottos {
    use aptos_std::debug::print;
    use aptos_framework::randomness;
    use lottos::test_helpers::setup;

    #[test]
    fun test_draw_list_number() {
        setup();

        let winning_numbers = vector[];

        for (i in 0..6) {
            let number = randomness::u64_range(1, 56); // Assuming 1-55 for Power 6/55
            while (winning_numbers.contains(&number)) {
                number = randomness::u64_range(1, 56);
            };
            winning_numbers.push_back(number);
        };

        print(&winning_numbers)
    }
}
