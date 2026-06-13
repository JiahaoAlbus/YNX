package types

import "testing"

func TestDefaultGenesisValidates(t *testing.T) {
	t.Parallel()

	if err := DefaultGenesis().Validate(); err != nil {
		t.Fatalf("expected default genesis to validate, got error: %v", err)
	}
}

func TestSystemConfigValidateRejectsBadEnabledConfig(t *testing.T) {
	t.Parallel()

	cfg := DefaultSystemConfig()
	cfg.Enabled = true
	cfg.DeployerAddress = "ynx1deployer"
	cfg.TeamBeneficiaryAddress = "ynx1team"
	cfg.TeamPercent = 10
	cfg.TreasuryPercent = 10
	cfg.CommunityPercent = 10

	if err := cfg.Validate(); err == nil {
		t.Fatal("expected invalid allocation sum to fail validation")
	}

	cfg.TeamPercent = 15
	cfg.TreasuryPercent = 40
	cfg.CommunityPercent = 45
	cfg.GenesisSupply = "not-a-number"
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected invalid numeric genesis supply to fail validation")
	}
}
