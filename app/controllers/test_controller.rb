require 'json'

class TestController < ApplicationController
  before_action :_check_jwt, only: [:auth, :reset_data]
  skip_before_action :verify_authenticity_token
  rescue_from JWT::VerificationError, with: :_handle_exception
  rescue_from Error, with: :_handle_exception

  def auth
    user = _get_user

    sign_in user, event: :authentication

    render plain: '{"result": "ok"}'
  rescue TestCredentialExpiredError => e
    render plain: "{\"result\": \"#{e.message}\"}", status: 418
  end

  def reset_data
    default_preferences = {
      sample_id: '1',
      reference_name: '1',
      start: '1',
      end: '1',
      reference_bases: '1',
      alternate_bases: '1',
      letter_genotype: '1',
      zygosity: '1',
      call_dp: '1',
      ad: '1',
      call_gq: '1',
      inheritance: '1',
      de_novo: '1',
      refseq_id: '1',
      gene_symbol: '1',
      effects_with_impacts: '1',
      a1000g_freq_max: '1',
      gnomad_genome_freq_max: '1',
      mssng_freq_max: '1',
      paths: '1',
      sex: '1',
      platform: '1',
      # igv: '1',
      # annotation_id: '1',
      category: '0',
      prioritizations: '0',
      gnomad_exome_freq_max: '0',
      exac_freq_max: '0',
      call_filter: '0',
      inherited_quality: '0',
      comp_het_rec: '0',
      entrez_id: '0',
      genotype_likelihood: '0',
      dbsnp: '0',
      clinvar_sig: '0',
      cgd_disease: '0',
      cgd_inheritance: '0',
      omim_phenotype: '0',
      call_phaseset: '0',
      effect_priority: '0',
      typeseq_priority: '0',
      affection: '0',
      familyid: '0',
      sanger_validated: '0',
      sanger_inheritance: '0',
    }

    user = _get_user
    user.update(preferences: default_preferences)
    user.variant_searches.saved.destroy_all
    user.variant_searches.not_saved.destroy_all
    user.gene_searches.saved.destroy_all
    user.gene_searches.not_saved.destroy_all
    user.subject_sample_searches.saved.destroy_all
    user.subject_sample_searches.not_saved.destroy_all
    user.trios.saved.destroy_all
    user.trios.not_saved.destroy_all

    render plain: '{"result": "ok"}'
  rescue Signet::AuthorizationError
    render plain: '{"result": "test_credential_expired"}', status: 418
  end

  def trigger_sample_error
    # This endpoint is for testing only.
    raise RuntimeError, 'Sample Error for Testing'
  end

  private

  def _handle_exception
    render plain: '{"result": "access_denied"}', status: 403
  end

  def _get_user
    data = JSON::parse request.body.read
    user = User.find_by(email: data['email'])

    if not user.authorized?
      raise TestCredentialExpiredError, 'Test credential expired'
    end

    user
  end

  def _check_jwt
    jwt_signature_secret = ENV['TEST_JWT_SECRET']

    if jwt_signature_secret.nil? or jwt_signature_secret.empty?
      raise RuntimeError, 'The endpoint is off-limited.'
    end

    bearer_token = request.headers['Authorization']
    given_jwt = nil

    if !bearer_token.nil? and !bearer_token.empty?
      given_jwt = bearer_token.sub(/^Bearer /, '')
    end

    if given_jwt.nil?
      raise RuntimeError, 'The access token is missing.'
    end

    # Validate the token.
    # NOTE: This endpoint intentionally does not handle the expired signature (JWT::ExpiredSignature).
    claims = JWT.decode given_jwt, jwt_signature_secret, true, { algorithm: 'HS512' }
  end
end

class TestCredentialExpiredError < StandardError
end
