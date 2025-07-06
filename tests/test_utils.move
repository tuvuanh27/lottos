#[test_only]
module lottos::test_utils {
    use lottos::utils::{combinations, sort};

    #[test]
    fun test_sort() {
        let numbers = vector[1, 22, 45, 15, 35, 32];
        let sorted = sort(numbers);
        assert!(sorted == vector[1, 15, 22, 32, 35, 45]);
    }

    #[test]
    fun test_combinations() {
        let numbers = vector[1, 2, 3, 4, 5, 6];
        let combinations = combinations(numbers, 5);

        // Should generate 6 combinations (6 choose 5 = 6)
        assert!(combinations.length() == 6);

        // Check each combination has exactly 5 elements
        let i = 0;
        while (i < combinations.length()) {
            assert!(combinations[i].length() == 5);
            i += 1;
        };

        // Check specific combinations
        let expected = vector[
            vector[1, 2, 3, 4, 5],
            vector[1, 2, 3, 4, 6],
            vector[1, 2, 3, 5, 6],
            vector[1, 2, 4, 5, 6],
            vector[1, 3, 4, 5, 6],
            vector[2, 3, 4, 5, 6]
        ];

        assert!(combinations == expected);
    }
}
