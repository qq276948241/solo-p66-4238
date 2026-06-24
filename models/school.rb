class School < ActiveRecord::Base
  has_many :users
  validates :name, presence: true
  validates :email_suffix, presence: true, uniqueness: true
end
