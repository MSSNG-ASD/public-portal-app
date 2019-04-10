class User < ApplicationRecord
  # Other devise modules are:
  # :confirmable, :lockable, :timeoutable,
  # :database_authenticatable, :registerable,
  # :recoverable, :rememberable, :trackable, :validatable

  # presently only google_oauth2 by omniauth
  devise :omniauthable, omniauth_providers: [:google_oauth2]

  # roles for ACL
  enum role: [:informaticist, :councelor, :physician, :patient, :admin]
  # initialize role (see: policies/user_policy.rb)
  after_initialize :initialize_role, if: :new_record?
  # initialize preferences (see: config/query.yml)
  after_initialize :initialize_preferences, if: :new_record?

  # user has many searches and searches belong to user
  has_many :gene_searches, dependent: :destroy
  has_many :subject_sample_searches, dependent: :destroy
  has_many :variant_searches, dependent: :destroy
  has_many :trios, dependent: :destroy

  # store preferences hash in text column with accessor for each
  store :preferences, accessors: Rails.configuration.x.query['selectable_preferences'].flatten

  # return a new or updated user from omniauth authorization
  def self.from_omniauth(auth)
    # Either create a User record or return it based on the provider (Google) and the UID
    user = where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
    	user.email = auth.info.email
    end
    # Only authorized users can sign in
    # Update assumes token was previously revoked on sign_out
    if BigQuery.authorized_token?(auth.credentials.token, auth.credentials.refresh_token, auth.credentials.expires_at)
      user.update(
        email: auth.info.email,
        token: auth.credentials.token,
        expires: auth.credentials.expires,
        expires_at: auth.credentials.expires_at,
        refresh_token: auth.credentials.refresh_token
      )
    end
    user
  end

  def authorized?
    BigQuery.authorized_token?(token, refresh_token, expires_at)
  end

  def credentials
    @credentials ||= Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.secrets[:google_client_id],
      client_secret: Rails.application.secrets[:google_secret],
      scope: Rails.configuration.x.query['scope'],
      access_token: token,
      refresh_token: refresh_token,
      expires_at: expires_at)
  end

  # return a fresh token
  def token
    if expires_at.to_i < Time.now.to_i && refresh_token.present?
      refresh_token!
    end
    self[:token]
  end

  def revoke_token
    response = HTTP.get("https://accounts.google.com/o/oauth2/revoke", params: {token: token})
    if response.code.eql?(200)
      puts "REVOKED"
    else
      puts response
    end
  end

  # return user selected preferences
  def selected_preferences
    selected_preferences = []
    selectable_prefs = Rails.configuration.x.query['selectable_preferences'].flatten
    selectable_prefs.each do |pref|
      selected_preferences << pref if self.send(pref.to_sym).eql?("1")
    end
    selected_preferences
  end

  private

  # update token using refresh_token
  def refresh_token!
    response = HTTP.post("https://accounts.google.com/o/oauth2/token", form: {
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: Rails.application.secrets[:google_client_id],
      client_secret: Rails.application.secrets[:google_secret]
    })
    data = JSON.parse(response.body)
    update(
      token: data['access_token'],
      expires_at: Time.now.to_i + (data['expires_in'] || 0)
    )
  end

  # set default preferences
  def initialize_preferences
    Rails.configuration.x.query['unselected_preferences'].map {|pref| self.preferences[pref] = "0"}
    Rails.configuration.x.query['selected_preferences'].map {|pref| self.preferences[pref] = "1"}
  end

  # set default role
  def initialize_role
    # too risky, need some other method
    # if User.count == 0
    #   self.role ||= :admin
    # else
    #   self.role ||= :informaticist
    # end
  end

end
