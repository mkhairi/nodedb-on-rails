class Location < ApplicationRecord
  self.table_name  = "locations"
  self.primary_key = "id"

  attribute :id,   :string
  attribute :name, :string
  attribute :lat,  :float
  attribute :lon,  :float

  validates :name, presence: true
  validates :lat,  presence: true, numericality: true
  validates :lon,  presence: true, numericality: true

  before_create { self.id ||= SecureRandom.uuid }
end
