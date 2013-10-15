require 'spec_helper'

feature "Badge Index" do
  
  given(:user) { FactoryGirl.create(:user) }
  given(:badge) { FactoryGirl.create(:badge) }

  background(:each) do
    visit new_user_session_path
    fill_in 'user[email]', :with => user.email
    fill_in 'user[password]', :with => 'password'
    click_link_or_button 'Sign in'
    visit badges_path
  end

  scenario "User sees correct titles" do
    page.should have_title("All Badges")
    page.should have_selector('h1', "All Badges")
  end

  scenario "User sees pagination" do
    #page.should have_selector('paginate')
    Badge.asc(:name).page(1).per(APP_CONFIG['page_size']).each do |badge|
      page.should have_selector('li', text: badge.name)
    end
  end

  scenario "User clicks New Badge button" do
    page.should have_link("New Badge")
    click_link "New Badge" 
    page.should have_selector('h1', text: "Create New Badge")
  end

end
