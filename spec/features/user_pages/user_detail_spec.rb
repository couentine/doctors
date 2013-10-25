require 'spec_helper'

feature "View User Profile" do
  
  given(:user) { FactoryGirl.create(:user) }
  given(:other_user) { FactoryGirl.create(:user) }

  background(:each) do
    visit new_user_session_path
    fill_in 'user[email]', :with => user.email
    fill_in 'user[password]', :with => 'password'
    click_button 'Sign in'
  end

  scenario "User sees all fields and controls on his own profile" do
    visit user_path(user)
    page.should have_text(user.name)
    page.should have_link("Change account info")
    page.should have_link("Change picture")
  end

  scenario "User sees all fields but no controls on another user profile" do
    visit user_path(other_user)
    page.should have_text(user.name)
    page.should_not have_link("Change account info")
    page.should_not have_link("Change picture")
  end

end
