require 'csv'


############# DICTIONARY PREPARE SEED ###############

words = []

# CSV word dictionary
CSV.foreach("./english_small_dict.csv") do |row| 
  words.push(row[0].to_s.upcase)
end

# Create buckets by word length
length_dict = words.group_by {|word| word.length}

$seed = {}
$answer = {:trace=>[], :words=>[]}


length_dict.each do |length, arr|
	$seed[length] = {
		:seed_arr => arr,
		:num_groups => {}
		};
end

################### FUNCTIONS TO BE USED ###################

# gives a number representing a string, used to get word combinations faster
def magic_num(str)	
	str.bytes.reduce(0) {|sum, c_bytes| sum+=c_bytes-64}
end


# Finds combinations of buckets whose sum of magic numbers equals magic number of input matrix
def skynet (target, blanks_words_sizes, index, track, trace)
	if index == 1
		$seed[ blanks_words_sizes[1] ][:num_groups].each do |key, obj|
			if(track + key < target && key != 0) 
				if( $seed[blanks_words_sizes[0]][:num_groups][target - (track+key)] )
					c = trace.dup
					c << [blanks_words_sizes[1], key]
					c << [blanks_words_sizes[0], target - (track+key)] 					
					$answer[:trace].push(c);
				end
			end
		end
	else 
		$seed[ blanks_words_sizes[index] ][:num_groups].each do |key, obj|	
			c = trace.dup		

			if(track + key < target && key != 0)
				c << [blanks_words_sizes[index], key]
				skynet(target, blanks_words_sizes, index - 1, track + key, c)
			else 
				# stop entering
			end
		end
	end
end


# Find if a base set of characters can contain a word's characters
def makes_word (base, word)
	temp = base.dup
	word.chars.each do |char|
		if base[char]
			temp.sub!(char, '')
		else 
			return false
		end
	end
	true
end


# Target_words are joined and alphabetically ordered to find match with input matrix
def unordered_match (target_word, matrix, ans_arr_el, index, track, trace)	
	if index == 0 
		$seed[ans_arr_el[0][0]][:num_groups][ans_arr_el[0][1]].each do |word|
			temp_word = track + word 
			if(target_word == temp_word.chars.sort.join)				
				temp_answer = trace.dup
				temp_answer.push(word)
				$answer[:words].push(temp_answer)				
			end
		end
	elsif index > 0
		$seed[ans_arr_el[index][0]][:num_groups][ans_arr_el[index][1]].each do |word|
			c = trace.dup
			c.push(word)
			unordered_match(target_word, matrix, ans_arr_el, index - 1, track + word, c)						
		end		
	end	
end


# Function which uses above to solve as much as the current algorithm can
# Finds if set of words in a particular answer possibilty can be made from matrix
def solver (seed_char, blanks_words_sizes, matrix)
	# Set numerical target
	target = magic_num(seed_char)	
	# Find magic number sum buckets
	skynet(target, blanks_words_sizes, blanks_words_sizes.length - 1, 0, [])
	# Alphabetical sort input matrix
	sorted_seed_char = seed_char.chars.sort.join	

	# Find unique sets from skynet solutions
	$answer[:trace].each do |arrOarr|
		arrOarr.sort!
	end 

	$answer[:trace].uniq!	
	
	# Finds match for complete set of words from skynet solutions
	$answer[:trace].each do |answer_arr_el|				
		unordered_match(sorted_seed_char, matrix, answer_arr_el, answer_arr_el.length - 1, "", [])
		# Can be ignored
		$ops += $seed[answer_arr_el[0][0]][:num_groups][answer_arr_el[0][1]].length *
			$seed[answer_arr_el[1][0]][:num_groups][answer_arr_el[1][1]].length *
			$seed[answer_arr_el[1][0]][:num_groups][answer_arr_el[1][1]].length *
			$seed[answer_arr_el[1][0]][:num_groups][answer_arr_el[1][1]].length		
	end
	
	return $answer[:words]
end


# Simple nearest 8 neighbours in a matrix (for connecting words)
def find_neighbors (matrix, i, j)
	neighbors = []
	row_limit = matrix.length;
	if row_limit > 0
		column_limit = matrix[0].length;
		x = [0, i-1].max
		
		while x <= [i+1, row_limit-1].min
			y = [0, j-1].max
			
			while y <= [j+1, column_limit].min
				if x != i || y != j					
					neighbors << {:char => matrix[x][y], :row_index => x, :col_index => y}
				end
				y += 1
			end
			
			x += 1
		end
	end
	neighbors
end


# The spider that connects words 'human'ly
def find_next (matrix, word, index, start_row, start_col)
	if(index < word.length - 1)
		neighbors = find_neighbors(matrix, start_row, start_col)
		
		neighbors.each do |neighborObj|			
			if neighborObj[:char] == word[index + 1]
				# print word, " - ", word[index], " ", neighborObj[:char], " ", neighborObj[:row_index], neighborObj[:col_index], "\n"
				coord = neighborObj[:row_index].to_s + '-' + neighborObj[:col_index].to_s
				find_next(matrix, word, index + 1, neighborObj[:row_index], neighborObj[:col_index])
			end
		end		
	elsif index == word.length - 1
		$find_next_found = true
	end
end


# Using previous 2 functions finds if word can be drawn in the matrix
def find_word_in_matrix (matrix, word)
	$find_next_found = false
	
	matrix.each_index do |row_index|		
		matrix[row_index].each_index do |col_index|
			if matrix[row_index][col_index] == word[0]							
				find_next(matrix, word, 0, row_index, col_index)
			end
		end
	end

	$find_next_found
end


# After possible answers for each buckets are found, 
# this function helps find next set after previous working answer is found
def solve_by_grouping (matrix, solver_results, i, trace, solution_trace)
	if i > 0
		flist = solver_results.group_by {|ans_arr| ans_arr[i]}
		flist.keys.each do |word|
			if(find_word_in_matrix(matrix, word))
				copy_trace = trace.dup.push(word)
				solve_by_grouping(matrix, flist[word], i - 1, copy_trace, solution_trace)
			end
		end			
	else
		flist = solver_results.group_by {|ans_arr| ans_arr[i]}
		flist.keys.each do |word|
			if(find_word_in_matrix(matrix, word))
				copy_trace = trace.dup.push(word)
				solution_trace << copy_trace
			end
		end		
	end
end


####################### ACTUAL PROGRAM EXECUTION STARTS #########################

$find_next_found = false
$ops = 0

print "Dictionary imported. To Start Press (y/n) :"

while gets.chomp.upcase == 'Y'	do	
	$answer = {:trace=>[], :words=>[]}
	matrix = []
	
	print "\nEnter number of rows: "
	rows = gets.chomp
	rows = Integer(rows)
	
	print "\nEnter problem with spaces for blank (press enter after every line):-\n"

	(1..rows).to_a.each do |index|
		matrix.push(gets.chomp.upcase.split(''))
	end	

	seed_char = matrix.flatten.join('').split(' ').join()
	
	print "\nEnter number of words: "
	seed_num_words = gets.chomp
	seed_num_words = Integer(seed_num_words)
	blanks_words_sizes = []

	(1..seed_num_words).to_a.each do |num|
		printer = "\nWord" + num.to_s + "'s length: "
		puts printer
		wlength = gets.chomp	
		blanks_words_sizes.push(Integer(wlength))
	end

	len_one = seed_char.length
	len_two = blanks_words_sizes.reduce(:+)
	
	# If valid input
	if len_one == len_two
		blanks_words_sizes.sort_by! {|size| size}		

		################### Setup an optimised seed #################
		$seed.each do |length, seed_obj| 
			seed_obj[:num_groups] = seed_obj[:seed_arr].group_by do |word|			
				if blanks_words_sizes.index(word.length) && makes_word(seed_char, word) && find_word_in_matrix(matrix, word)
					magic_num(word)
				else		
					0	# Note: Could be thrown away instead to save memory
				end
			end	
		end		
		####################### Seed setup ends ##########################


		################## Problem solving begins ########################

		print "\nINPUT IS VALID"

		solver_results = solver(seed_char, blanks_words_sizes, matrix)
		
		print "\n\nN Basanti moves = ", $ops

		print "\n\nComputer's effort has ended"
		
		solver_results.each do |ans_arr|
			ans_arr.sort_by! {|word| word.length}		
		end		
		
		solution_trace = []				

		# Prepare solution for interface
		solve_by_grouping(matrix, solver_results, seed_num_words - 1, [], solution_trace)		

		####################### Problem Solved  ############################


		###################  Interface For User Playing Begins #############

		print "\n\nProblem has been solved partly, now play along to help the computer"

	    solution_trace.each do |ans_arr|
			ans_arr.sort_by! {|word| word.length}			
		end

		solution = []			
		i = 0;

		while i < seed_num_words
			solution_hash = solution_trace.group_by {|ans_arr| ans_arr[i]}
			
			print "\n\nOptions for ", blanks_words_sizes[i].to_s, " lettered word are ", solution_hash.keys

			if i < seed_num_words - 1
				print "\n\nEnter working option: "
				working_option = gets.chomp
				working_option = working_option.upcase
				solution << working_option
				solution_trace = solution_hash[working_option]
				if !solution_trace
					break
				end
			end
			i += 1
		end 

		############################ Interface Ends ###############################							
	end
	print "\n\nNext Round? (y/n) :"
end




