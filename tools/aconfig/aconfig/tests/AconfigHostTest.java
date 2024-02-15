import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;


import com.android.aconfig.test.FakeFeatureFlagsImpl;
import com.android.aconfig.test.FeatureFlags;
import com.android.aconfig.test.FeatureFlagsImpl;
import com.android.aconfig.test.Flags;

@RunWith(JUnit4.class)
public final class AconfigHostTest {
    @Test
    public void testThrowsExceptionIfFlagNotSet() {
        assertThrows(NullPointerException.class, () -> Flags.disabledRo());
        FakeFeatureFlagsImpl featureFlags = new FakeFeatureFlagsImpl();
        assertThrows(IllegalArgumentException.class, () -> featureFlags.disabledRo());
    }

    @Test
    public void testSetFlagInFakeFeatureFlagsImpl() {
        FakeFeatureFlagsImpl featureFlags = new FakeFeatureFlagsImpl();
        featureFlags.setFlag(Flags.FLAG_ENABLED_RW, true);
        assertTrue(featureFlags.enabledRw());
        featureFlags.setFlag(Flags.FLAG_ENABLED_RW, false);
        assertFalse(featureFlags.enabledRw());

        //Set Flags
        assertThrows(NullPointerException.class, () -> Flags.enabledRw());
        Flags.setFeatureFlags(featureFlags);
        featureFlags.setFlag(Flags.FLAG_ENABLED_RW, true);
        assertTrue(Flags.enabledRw());
        Flags.unsetFeatureFlags();
    }

    @Test
    public void testSetFlagWithRandomName() {
        FakeFeatureFlagsImpl featureFlags = new FakeFeatureFlagsImpl();
        assertThrows(IllegalArgumentException.class,
            () -> featureFlags.setFlag("Randome_name", true));
    }

    @Test
    public void testResetFlagsInFakeFeatureFlagsImpl() {
        FakeFeatureFlagsImpl featureFlags = new FakeFeatureFlagsImpl();
        featureFlags.setFlag(Flags.FLAG_ENABLED_RO, true);
        assertTrue(featureFlags.enabledRo());
        featureFlags.resetAll();
        assertThrows(IllegalArgumentException.class, () -> featureFlags.enabledRo());

        // Set value after reset
        featureFlags.setFlag(Flags.FLAG_ENABLED_RO, false);
        assertFalse(featureFlags.enabledRo());
    }

    @Test
    public void testFlagsSetFeatureFlags() {
        FakeFeatureFlagsImpl featureFlags = new FakeFeatureFlagsImpl();
        featureFlags.setFlag(Flags.FLAG_ENABLED_RW, true);
        assertThrows(NullPointerException.class, () -> Flags.enabledRw());
        Flags.setFeatureFlags(featureFlags);
        assertTrue(Flags.enabledRw());
        Flags.unsetFeatureFlags();
    }

    @Test
    public void testFlagsUnsetFeatureFlags() {
        FakeFeatureFlagsImpl featureFlags = new FakeFeatureFlagsImpl();
        featureFlags.setFlag(Flags.FLAG_ENABLED_RW, true);
        assertThrows(NullPointerException.class, () -> Flags.enabledRw());
        Flags.setFeatureFlags(featureFlags);
        assertTrue(Flags.enabledRw());

        Flags.unsetFeatureFlags();
        assertThrows(NullPointerException.class, () -> Flags.enabledRw());
    }

    @Test
    public void testFeatureFlagsImplNotImpl() {
        FeatureFlags featureFlags = new FeatureFlagsImpl();
        assertThrows(UnsupportedOperationException.class,
            () -> featureFlags.enabledRw());
    }
}
