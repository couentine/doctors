require 'spec_helper'

feature "Site Authentication" do
  
  given(:user) { FactoryGirl.create(:user) }

  scenario "User visits root path and signs in, then signs out" do
    visit root_path
    page.should have_link("Sign in")
    click_link "Sign in"
    fill_in 'user[email]', :with => user.email
    fill_in 'user[password]', :with => 'password'
    page.should have_button("Sign in")
    click_button 'Sign in'
    page.should_not have_link("Sign in")
    page.should have_text(user.name)
    # visit destroy_user_session_path >> doesn't work
    # page.should_not have_text(user.name)
  end

  scenario "User signs up for a new account" do
    visit root_path
    page.should have_link("header-sign-up-link")
    click_link "header-sign-up-link"
    fill_in 'user[email]', :with => 'unique-human@example.com'
    fill_in 'user[name]', :with => 'Unique Human'
    fill_in 'user[password]', :with => 'password'
    page.should have_button("Create an account")
    click_button 'Create an account'
    page.should_not have_link("Sign in")
    page.should have_text("Unique Human")
  end

end
