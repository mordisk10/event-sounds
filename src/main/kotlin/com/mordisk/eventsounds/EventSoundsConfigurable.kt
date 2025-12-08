package com.mordisk.eventsounds

import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.options.Configurable
import com.intellij.openapi.ui.TextFieldWithBrowseButton
import javax.swing.*

class EventSoundsConfigurable : Configurable {
    private var mainPanel: JPanel? = null

    private lateinit var enableRunStart: JCheckBox
    private lateinit var runStartPath: TextFieldWithBrowseButton

    private lateinit var enableRunNotStarted: JCheckBox
    private lateinit var runNotStartedPath: TextFieldWithBrowseButton

    override fun getDisplayName(): String = "Event Sounds"

    override fun createComponent(): JComponent {
        if (mainPanel == null) {
            val panel = JPanel()
            panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
            panel.border = BorderFactory.createEmptyBorder(8, 8, 8, 8)

            // Run Started section
            enableRunStart = JCheckBox("Play sound when Run starts")
            runStartPath = TextFieldWithBrowseButton()
            runStartPath.addBrowseFolderListener(
                "Select Custom MP3 for Run Start",
                null,
                null,
                FileChooserDescriptorFactory.createSingleFileDescriptor("mp3")
            )

            val runStartRow = JPanel()
            runStartRow.layout = BoxLayout(runStartRow, BoxLayout.X_AXIS)
            runStartRow.add(JLabel("Run Start sound:"))
            runStartRow.add(Box.createHorizontalStrut(8))
            runStartRow.add(runStartPath)

            panel.add(enableRunStart)
            panel.add(Box.createVerticalStrut(4))
            panel.add(runStartRow)

            panel.add(Box.createVerticalStrut(12))

            // Run Not Started section
            enableRunNotStarted = JCheckBox("Play sound when Run fails to start")
            runNotStartedPath = TextFieldWithBrowseButton()
            runNotStartedPath.addBrowseFolderListener(
                "Select Custom MP3 for Failed Runs",
                null,
                null,
                FileChooserDescriptorFactory.createSingleFileDescriptor("mp3")
            )

            val notStartedRow = JPanel()
            notStartedRow.layout = BoxLayout(notStartedRow, BoxLayout.X_AXIS)
            notStartedRow.add(JLabel("Run Failed sound:"))
            notStartedRow.add(Box.createHorizontalStrut(8))
            notStartedRow.add(runNotStartedPath)

            panel.add(enableRunNotStarted)
            panel.add(Box.createVerticalStrut(4))
            panel.add(notStartedRow)

            mainPanel = panel
        }

        reset()
        return mainPanel as JPanel
    }

    override fun isModified(): Boolean {
        val state = EventSoundsSettings.getInstance().state
        return enableRunStart.isSelected != state.enableOnRunStart ||
                enableRunNotStarted.isSelected != state.enableOnRunNotStarted ||
                runStartPath.text != (state.customRunStartPath) ||
                runNotStartedPath.text != (state.customRunNotStartedPath)
    }

    override fun apply() {
        val service = EventSoundsSettings.getInstance()
        val st = service.state
        st.enableOnRunStart = enableRunStart.isSelected
        st.enableOnRunNotStarted = enableRunNotStarted.isSelected
        st.customRunStartPath = runStartPath.text
        st.customRunNotStartedPath = runNotStartedPath.text
    }

    override fun reset() {
        val state = EventSoundsSettings.getInstance().state
        enableRunStart.isSelected = state.enableOnRunStart
        enableRunNotStarted.isSelected = state.enableOnRunNotStarted
        runStartPath.text = state.customRunStartPath
        runNotStartedPath.text = state.customRunNotStartedPath
    }

    override fun disposeUIResources() {
        mainPanel = null
    }
}
