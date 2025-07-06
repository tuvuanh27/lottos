module lottos::utils {
    /// Sorts a vector of numbers using insertion sort algorithm.
    /// Optimized for small arrays (typically 6 elements for lottery numbers).
    /// Time complexity: O(n²) worst case, O(n) best case
    /// Space complexity: O(1) - sorts in place
    public fun sort(numbers: vector<u64>): vector<u64> {
        let len = numbers.length();

        // Handle edge cases
        if (len <= 1) {
            return numbers
        };

        let i = 1;
        while (i < len) {
            let key = numbers[i];
            let j = i;

            // Move elements that are greater than key one position ahead
            while (j > 0 && numbers[j - 1] > key) {
                let prev_val = numbers[j - 1];
                *numbers.borrow_mut(j) = prev_val;
                j -= 1;
            };

            // Place key at its correct position
            *numbers.borrow_mut(j) = key;
            i += 1;
        };

        numbers
    }

    /// Generate all combinations of k elements from an array of n elements
    /// For example: from [1,2,3,4,5,6], generate all 5-element combinations
    /// Returns: [[1,2,3,4,5], [1,2,3,4,6], [1,2,3,5,6], [1,2,4,5,6], [1,3,4,5,6], [2,3,4,5,6]]
    public fun combinations(numbers: vector<u64>, k: u64): vector<vector<u64>> {
        let n = numbers.length();
        let result = vector[];

        if (k > n || k == 0) {
            return result
        };

        // Generate combinations using iterative approach
        let indices = vector[];
        let i = 0;
        while (i < k) {
            indices.push_back(i);
            i += 1;
        };

        loop {
            // Create current combination
            let combination = vector[];
            let j = 0;
            while (j < k) {
                combination.push_back(numbers[indices[j]]);
                j += 1;
            };
            result.push_back(combination);

            // Find the rightmost index that can be incremented
            let pos = k - 1;
            while (pos < k && indices[pos] == n - k + pos) {
                if (pos == 0) break;
                pos -= 1;
            };

            // If no such index exists, we're done
            if (pos < k && indices[pos] == n - k + pos) {
                break
            };

            // Increment the found index
            *indices.borrow_mut(pos) = indices[pos] + 1;

            // Reset all indices to the right
            let reset_pos = pos + 1;
            while (reset_pos < k) {
                *indices.borrow_mut(reset_pos) = indices[reset_pos - 1] + 1;
                reset_pos += 1;
            };
        };

        result
    }

    /// Generate 5-number combinations from a 6-number array
    /// This is a specialized function for the common case
    public fun generate_5_from_6(numbers: vector<u64>): vector<vector<u64>> {
        assert!(numbers.length() == 6, 1); // Error if not exactly 6 numbers
        combinations(numbers, 5)
    }
}
