/*
 * Venturify Pro — draft-only feature module.
 *
 * IMPORTANT:
 * - This file is intentionally NOT imported by index.html.
 * - It lives on draft/pro-plan-and-free-limits, not the live deployment branch.
 * - This is an integration foundation, not a payment/subscription implementation.
 */
(function (root) {
  'use strict';

  const PLANS = Object.freeze({
    free: Object.freeze({
      id: 'free',
      label: 'Free',
      communitiesCreated: Infinity,
      coFounderConnections: Infinity,
      posts: Infinity,
      follows: Infinity,
      advancedFounderFilters: false,
      profileCustomization: false,
      canCreateAds: false,
      canRunAds: false,
      communityManagementTools: false
    }),
    pro: Object.freeze({
      id: 'pro',
      label: 'Venturify Pro',
      communitiesCreated: Infinity,
      coFounderConnections: Infinity,
      posts: Infinity,
      follows: Infinity,
      advancedFounderFilters: true,
      profileCustomization: true,
      canCreateAds: true,
      canRunAds: true,
      communityManagementTools: true
    })
  });

  const AD_RULES = Object.freeze({
    titleMax: 70,
    descriptionMax: 240,
    destinationProtocols: ['https:'],
    placement: 'in_feed',
    label: 'Sponsored'
  });

  function normalizePlan(profile) {
    return profile && String(profile.subscription_tier || '').toLowerCase() === 'pro'
      ? 'pro'
      : 'free';
  }

  function getEntitlements(profile) {
    return PLANS[normalizePlan(profile)];
  }

  function canCreateCommunity(profile) {
    return getEntitlements(profile).communitiesCreated === Infinity ||
      Number(profile && profile.communities_created_count || 0) <
      getEntitlements(profile).communitiesCreated;
  }

  function canConnectWithCoFounder(profile) {
    return getEntitlements(profile).coFounderConnections === Infinity ||
      Number(profile && profile.co_founder_connections_count || 0) <
      getEntitlements(profile).coFounderConnections;
  }

  function safeHttpsUrl(value) {
    try {
      const url = new URL(String(value || '').trim());
      return url.protocol === 'https:' ? url.href : '';
    } catch (_) {
      return '';
    }
  }

  function validateAdDraft(input) {
    const ad = input || {};
    const title = String(ad.title || '').trim();
    const description = String(ad.description || '').trim();
    const destinationUrl = safeHttpsUrl(ad.destination_url);
    const imageUrl = ad.image_url ? safeHttpsUrl(ad.image_url) : '';

    const errors = [];
    if (title.length < 3 || title.length > AD_RULES.titleMax) {
      errors.push('Ad title must be 3–70 characters.');
    }
    if (description.length < 10 || description.length > AD_RULES.descriptionMax) {
      errors.push('Ad description must be 10–240 characters.');
    }
    if (!destinationUrl) errors.push('Use a valid HTTPS destination link.');
    if (ad.image_url && !imageUrl) errors.push('The image must use a valid HTTPS URL.');
    if (ad.status && !['draft', 'pending_review', 'approved', 'paused', 'rejected'].includes(ad.status)) {
      errors.push('Invalid ad status.');
    }

    return {
      valid: errors.length === 0,
      errors,
      value: {
        title,
        description,
        destination_url: destinationUrl,
        image_url: imageUrl,
        placement: AD_RULES.placement,
        status: 'draft'
      }
    };
  }

  function renderProBadge() {
    return '<span class="venturify-pro-badge" title="Venturify Pro member">✦ PRO</span>';
  }

  function renderSponsoredCard(ad) {
    const safe = value => String(value == null ? '' : value).replace(/[&<>"']/g, ch => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[ch]));
    const destination = safeHttpsUrl(ad && ad.destination_url);
    if (!ad || ad.status !== 'approved' || !destination) return '';
    const image = safeHttpsUrl(ad.image_url);
    return '<article class="venturify-sponsored-card" data-ad-id="' + safe(ad.id) + '">' +
      '<div class="venturify-sponsored-label">Sponsored</div>' +
      (image ? '<a href="' + safe(image) + '" target="_blank" rel="noopener noreferrer" tabindex="-1" aria-hidden="true"><img src="' + safe(image) + '" alt="" loading="lazy"></a>' : '') +
      '<h3>' + safe(ad.title) + '</h3>' +
      '<p>' + safe(ad.description) + '</p>' +
      '<a class="venturify-sponsored-cta" href="' + safe(destination) + '" target="_blank" rel="noopener noreferrer" data-ad-click="' + safe(ad.id) + '">Learn more ↗</a>' +
      '</article>';
  }

  function filterFounderResults(founders, filters) {
    const f = filters || {};
    const terms = String(f.query || '').toLowerCase().trim().split(/\s+/).filter(Boolean);
    return (founders || []).filter(founder => {
      const text = [
        founder.headline, founder.company, founder.location, founder.skills,
        founder.looking_for, founder.bio, founder.display_name, founder.username
      ].join(' ').toLowerCase();
      if (!terms.every(term => text.includes(term))) return false;
      if (f.location && !String(founder.location || '').toLowerCase().includes(String(f.location).toLowerCase())) return false;
      if (f.skills) {
        const skills = String(founder.skills || '').toLowerCase();
        if (!skills.includes(String(f.skills).toLowerCase())) return false;
      }
      if (f.openToCoFounders && !/co.?founder|collaborat|partner|team|teammate/i.test(founder.looking_for || '')) return false;
      return true;
    });
  }

  root.VenturifyProDraft = Object.freeze({
    plans: PLANS,
    adRules: AD_RULES,
    normalizePlan,
    getEntitlements,
    canCreateCommunity,
    canConnectWithCoFounder,
    validateAdDraft,
    renderProBadge,
    renderSponsoredCard,
    filterFounderResults
  });
})(typeof window !== 'undefined' ? window : globalThis);
