/// # Lottery Utility Functions
/// 
/// Provides helper functions for lottery number processing:
/// - **Sorting**: Efficient in-place sorting for small lottery number sets
/// - **Combinations**: Generate mathematical combinations for prize calculations
/// 
/// ## Performance Characteristics
/// - Optimized for small data sets (typically 5-6 lottery numbers)
/// - In-place operations minimize memory allocations
/// - Deterministic algorithms ensure consistent results
/// 
/// ## Use Cases
/// - Normalizing ticket numbers for consistent storage/comparison
/// - Generating possible winning combinations for Jackpot2 prizes  
/// - Mathematical operations on lottery number sets
module lottos::utils {
    /// Sort a vector of numbers using insertion sort algorithm
    /// 
    /// Insertion sort is optimal for small arrays like lottery numbers.
    /// Sorts in-place for memory efficiency and returns the sorted vector.
    /// 
    /// # Parameters  
    /// * `numbers` - Vector of lottery numbers to sort
    /// 
    /// # Returns
    /// * `vector<u64>` - Same vector sorted in ascending order
    /// 
    /// # Performance
    /// - **Time Complexity**: O(n²) worst case, O(n) best case (already sorted)
    /// - **Space Complexity**: O(1) - sorts in place
    /// - **Optimal for**: Small arrays (≤ 10 elements)
    /// 
    /// # Examples
    /// ```move
    /// let numbers = vector[5, 2, 8, 1, 9];
    /// let sorted = sort(numbers); // Returns [1, 2, 5, 8, 9]
    /// ```
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

    /// Generate all mathematical combinations of k elements from n elements
    /// 
    /// Produces all possible ways to choose k items from the input vector
    /// without regard to order. Uses iterative algorithm for efficiency.
    /// 
    /// # Parameters
    /// * `numbers` - Source vector to choose elements from
    /// * `k` - Number of elements to choose in each combination
    /// 
    /// # Returns
    /// * `vector<vector<u64>>` - All possible k-element combinations
    /// 
    /// # Mathematical Background
    /// - Total combinations = C(n,k) = n! / (k! * (n-k)!)
    /// - For lottery: C(6,5) = 6 possible combinations
    /// 
    /// # Examples
    /// ```move
    /// // Generate all 5-element combinations from 6 numbers
    /// let numbers = vector[1,2,3,4,5,6];
    /// let combos = combinations(numbers, 5);
    /// // Returns: [[1,2,3,4,5], [1,2,3,4,6], [1,2,3,5,6], 
    /// //           [1,2,4,5,6], [1,3,4,5,6], [2,3,4,5,6]]
    /// ```
    /// 
    /// # Performance
    /// - **Time Complexity**: O(C(n,k) * k) 
    /// - **Space Complexity**: O(C(n,k) * k)
    /// - **Use Case**: Calculating Jackpot2 winning combinations
    /// 
    /// # Edge Cases
    /// - Returns empty vector if k > n or k == 0
    /// - Handles k == n by returning single combination with all elements
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

    /// Generate 5-number combinations from exactly 6 numbers
    /// 
    /// Specialized function for Power 6/55 Jackpot2 calculation.
    /// Wraps the general combinations function with validation for the
    /// specific use case of generating all ways to match 5 out of 6 numbers.
    /// 
    /// # Parameters
    /// * `numbers` - Vector containing exactly 6 lottery numbers
    /// 
    /// # Returns
    /// * `vector<vector<u64>>` - All 6 possible 5-number combinations
    /// 
    /// # Use Case
    /// In Power 6/55, Jackpot2 is won by matching 5 out of 6 main numbers
    /// plus the extra number. This function generates all possible 5-number
    /// combinations that could win Jackpot2 when combined with the extra.
    /// 
    /// # Examples
    /// ```move
    /// let winning_numbers = vector[10, 20, 30, 40, 50, 60];
    /// let jackpot2_combos = generate_5_from_6(winning_numbers);
    /// // Returns 6 combinations, each missing one of the original numbers
    /// ```
    /// 
    /// # Validation
    /// - Input must be exactly 6 numbers
    /// - Function will abort if length is not 6
    /// 
    /// # Aborts
    /// * Error code 1 - If input vector doesn't contain exactly 6 numbers
    public fun generate_5_from_6(numbers: vector<u64>): vector<vector<u64>> {
        assert!(numbers.length() == 6, 1); // Error if not exactly 6 numbers
        combinations(numbers, 5)
    }
}
