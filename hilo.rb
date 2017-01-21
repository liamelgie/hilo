require 'selenium-webdriver'											# Require the Selenium WebDriver (https://rubygems.org/gems/selenium-webdriver/versions/2.53.0)
require 'mysql2'														# Require mysql2 (https://rubygems.org/gems/mysql2)

# Gaudy ASCII Art
puts "\n"
puts "      ___                                     ___     "
puts "     \/\\  \\                                   \/\   \\    "
puts "     \\:\\  \\       ___                       \/::\\  \\   "
puts "      \\:\\  \\     \/\\__\\                     \/:\/\\:\\  \\  "
puts "  ___ \/::\\  \\   \/:\/__\/      ___     ___   \/:\/  \\:\\  \\ "
puts " \/\\  \/:\/\\:\\__\\ \/::\\  \\     \/\\  \\   \/\\__\\ \/:\/__\/ \\:\\__\\"
puts " \\:\\\/:\/  \\\/__\/ \\\/\\:\\  \\__  \\:\\  \\ \/:\/  \/ \\:\\  \\ \/:\/  \/"
puts "  \\::\/__\/       ~~\\:\\\/\\__\\  \\:\\  \/:\/  \/   \\:\\  \/:\/  \/ "
puts "   \\:\\  \\          \\::\/  \/   \\:\\\/:\/  \/     \\:\\\/:\/  \/  "
puts "    \\:\\__\\         \/:\/  \/     \\::\/  \/       \\::\/  \/   "
puts "     \\\/__\/         \\\/__\/       \\\/__\/         \\\/__\/    "
puts "\n                               Developed by Liam Elgie"
puts "\n"

print "Initialising"
ENV['Path'] += ";#{Dir.pwd}"; print "." 								# Temporarily add current directory to path (Allows access to the geckodriver)
client = Mysql2::Client.new(:host => "ohmykirigiri.com", :username => "hilo", :password => "583m2H56KcwfMjuD",:database => "hilo"); print "." 	 # Configure MySQL
driver = Selenium::WebDriver.for(:firefox); print "." 					# Configure Selenium WebDriver
driver.get("http://www.higherlowergame.com/"); print "."				# Navigate to the higherlower game
sleep(1); print "."														# Wait for the start button to appear
start_button = driver.find_element(:id, "game-start-btn")				# Select and click the start button to begin the game
start_button.click
sleep(1)																# Wait for the game to start
print ". Done!"; puts "\n"

def vote_higher(driver)													# Votes that the next card has a higher score
	higher_button = driver.find_element(:id, 'game-higher-btn')
	higher_button.click
end

def vote_lower(driver)													# Votes that the next card has a lower score
	lower_button = driver.find_element(:id, 'game-lower-btn')
	lower_button.click
end

def get_next_card(driver)												# Gets the name of the next card
	return driver.find_element(:css, 'div.card--current > h1.card__title').text
end

def get_previous_card(driver)											# Gets the name of the previous card
	return driver.find_element(:css, 'div.card--prev > h1.card__title').text
end

def get_previous_card_score(driver)										# Gets the score of the previous card
	return driver.find_element(:css, 'div.card--prev > h2.card__search-number').text
end

def get_current_round_score(driver)										# Gets the score of the current round
	return driver.find_element(:css, 'span.score-block__number').text
end

def get_final_round_score(driver)										# Gets the final score of the round
	return driver.find_element(:css, 'div.game-over__score').text
end

def query_next_card_score(driver, client)								# Queries the score of the next card
	statement = client.prepare("SELECT score FROM dictionary WHERE name=?")
	results = statement.execute(get_next_card(driver))
	if results.count == 0
		false
	else
		results.each do |row|
			return row["score"]
		end
	end
end

def check_game_over(driver)												# Checks whether the game has finished
	if driver.find_element(:css, "div.game-over__score").text == ""		# Div is only visible when the game has ended
		return true
	else
		return false
	end
end

def submit_record(client, driver, previous_card, previous_card_score)	# Submits the name and score of the previous card to the dictionary
	previous_card_score = previous_card_score.gsub(/[,]/, "").to_i
	def record_exists(client, previous_card)							# Checks if the card already exists within the dictionary
		statement = client.prepare("SELECT * FROM dictionary WHERE name=?")
		result = statement.execute(previous_card)
		if result.count == 0
			true
		else
			false
		end
	end
	if record_exists(client, previous_card)								# Inserts the new card into the database if it does not already exist
		statement = client.prepare("INSERT INTO dictionary (name, score) VALUES (?, ?)")
		result = statement.execute(previous_card, previous_card_score)
		puts "#{previous_card} (with a score of #{previous_card_score}) has been added to the dictionary"
	else 																# If the card already exists, its score is updated instead (to prevent the data from becoming out of date)
		statement = client.prepare("UPDATE dictionary SET score=? WHERE name=?")
		result = statement.execute(previous_card_score, previous_card)
		# puts "#{previous_card} (with a score of #{previous_card_score}) has been updated" 	# Commented out to prevent too much output
	end
end

def submit_round(driver, client, round_score)							# Insert the final score of the round to the database
	statement = client.prepare("INSERT INTO rounds (score) VALUES (?)")
	result = statement.execute(round_score)
end

def game_over(driver, client)											# Handles when the round ends
	submit_round(driver, client, get_final_round_score(driver))			# Submits the round to the database
	play_again_button = driver.find_element(:id, 'game-over-btn')		# Selects and clicks the 'play again' button
	play_again_button.click
	sleep(3)															# Waits for a new game to start
	play_round(driver, client)											# Repeat the main logic until game over
end

def play_round(driver, client)											# Begins a new round
	while check_game_over(driver) do 									# Continues to loop until the round is over
		submit_record(client, driver, get_previous_card(driver), get_previous_card_score(driver))
		if !query_next_card_score(driver, client)						# This block is unused if the dictionary has already been fully populated
			roll = rand(2) 												# Randomly rolls if the correct answer is not found (allowing the bot to continue and collect data)
			if (roll == 0)
				puts "A #{roll} has been rolled. Rolling higher"
				vote_higher(driver)										# Votes higher
			else 
				puts "A #{roll} has been rolled. Rolling lower"
				vote_lower(driver)										# Votes lower
			end
		else 
			next_card_name = get_next_card(driver)						# Gets the name of the next card
			next_card_score = query_next_card_score(driver, client) 	# Gets the score of the next card
			previous_card_name = get_previous_card(driver)				# Gets the name of the previous card
			previous_card_score = get_previous_card_score(driver)		# Gets the score of the previous card	
			if next_card_score.to_i > previous_card_score.gsub(/[,]/, "").to_i # Compares scores and selects the correct answer
				print "#{previous_card_name} (#{previous_card_score}) vs #{next_card_name} (#{next_card_score})".ljust(80) 
				print "#{next_card_name} wins! \n"
				vote_higher(driver)
			else 
				print "#{previous_card_name} (#{previous_card_score}) vs #{next_card_name} (#{next_card_score})".ljust(80) 
				print "#{previous_card_name} wins! \n"
				vote_lower(driver)
			end
		end	
		sleep(4)														# Waits for a new card to be drawn
	end
	# GAME OVER
	game_over(driver, client)											# Handles when the round ends								
end

def shutdown() 															# Exits the program	
	puts "\n"
	puts "Submitting round to database and exiting..."
	puts "\n"
	submit_round(driver, client, get_current_round_score(driver))		# Submits the round to the database
	driver.quit															# Quits the driver
	exit 130															# Exits the program
end

begin 																	# Begin main logic
	play_round(driver, client)											
ensure																	# Ensure clean shutdown
	shutdown()
end