require 'factory_girl'

FactoryGirl.define do
  factory :post, class: MyApp::Post do
    skip_create
    sequence(:id) {|n| n }
    sequence(:title) {|n| "Title for Post #{n}" }
    sequence(:body) {|n| "Body for Post #{n}" }
  end

  factory :comment, class: MyApp::Comment do
    skip_create
    sequence(:id) {|n| n }
    sequence(:body) {|n| "Body for Comment #{n}" }
  end

  factory :user, class: MyApp::User do
    skip_create
    sequence(:id) {|n| n }
    sequence(:name) {|n| "User ##{n}"}
  end
end
