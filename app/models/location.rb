class Location < ApplicationRecord
  include NameMaster
  has_many :users, dependent: :restrict_with_error
end
