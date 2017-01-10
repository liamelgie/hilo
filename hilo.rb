require 'selenium-webdriver'
require 'mysql2'

client = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "hilo")

driver = Selenium::WebDriver.for(:firefox)
driver.get("http://www.higherlowergame.com/")
sleep(1)
start_button = driver.find_element(:id, "game-start-btn")
start_button.click
sleep(1)

def vote_higher(driver)
	higher_button = driver.find_element(:id, 'game-higher-btn')
	higher_button.click
rescue
end

def vote_lower(driver)
	lower_button = driver.find_element(:id, 'game-lower-btn')
	lower_button.click
rescue 
end

def print_data(driver)
	previous_card = driver.find_element(:css, 'div.card--prev > h1.card__title').text
	previous_card_score = driver.find_element(:css, 'div.card--prev > h2.card__search-number').text
	next_card = driver.find_element(:css, 'div.card--current > h1.card__title').text
	score = driver.find_element(:css, 'div.score-block--current-score > span.score-block__number').text
	puts "Previous Card: " + previous_card
	puts "Previous Card Score : " + previous_card_score
	puts "Next Card: " + next_card
	puts "Score : " + score
end

def get_next_card(driver)
	return driver.find_element(:css, 'div.card--current > h1.card__title').text
end

def get_previous_card(driver)
	return previous_card = driver.find_element(:css, 'div.card--prev > h1.card__title').text
end

def get_previous_card_score(driver)
	return previous_card_score = driver.find_element(:css, 'div.card--prev > h2.card__search-number').text
end

def get_round_score(driver)
	return round_score = driver.find_element(:css, 'div.game-over__score').text
end

def query_new_card_score(driver, client)
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

def check_game_over(driver)
	if driver.find_element(:css, "div.game-over__score").text == ""
		return true
	else
		return false
	end
end

def submit_record(client, driver, previous_card, previous_card_score)
	previous_card_score = previous_card_score.gsub(/[,]/, "").to_i
	def record_exists(client, previous_card)
		statement = client.prepare("SELECT * FROM dictionary WHERE name=?")
		result = statement.execute(previous_card)
		if result.count == 0
			true
		else
			false
		end
	end
	if record_exists(client, previous_card)
		statement = client.prepare("INSERT INTO dictionary (name, score) VALUES (?, ?)")
		result = statement.execute(previous_card, previous_card_score)
		puts "New Record Added!"
	else 
		statement = client.prepare("UPDATE dictionary SET score=? WHERE name=?")
		result = statement.execute(previous_card_score, previous_card)
		puts "Old Record Updated!"
	end
end

def submit_round(driver, client, round_score)
	statement = client.prepare("INSERT INTO rounds (score) VALUES (?)")
	result = statement.execute(round_score)
end

def new_round(driver, client)
	while check_game_over(driver) do 
		submit_record(client, driver, get_previous_card(driver), get_previous_card_score(driver))

		if !query_new_card_score(driver, client)
			roll = rand(2) #Random rolls to generate results
			puts "No data found: Rolling die... Rolled a " + roll.to_s + "!"
			if (roll == 0)
				vote_higher(driver)
			else 
				vote_lower(driver)
			end
		else 
			puts "Data found. Making an educated guess ;)"
			if query_new_card_score(driver, client).to_i > get_previous_card_score(driver).gsub(/[,]/, "").to_i
				vote_higher(driver)
			else 
				vote_lower(driver)
			end
		end	
		sleep(4)
	end
	submit_round(driver, client, get_round_score(driver))
	play_again_button = driver.find_element(:id, 'game-over-btn')
	play_again_button.click
	sleep(3)
	new_round(driver, client)
end

new_round(driver, client)

driver.quit